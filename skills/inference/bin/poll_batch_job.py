#!/usr/bin/env python3
"""Poll a Roboflow Batch Processing job until it reaches a terminal state.

The script is directly executable (shebang + exec bit set in git). Invoke as:

    ./poll_batch_job.py <job_id> [--interval SECONDS] [--max-wait SECONDS]

Or with an explicit interpreter:

    python poll_batch_job.py <job_id> [--interval SECONDS] [--max-wait SECONDS]

Requires:
    export ROBOFLOW_API_KEY=...
    pip install "inference-cli>=0.9,<0.42"   # pinned: this script imports
                                             # inference_cli.lib internals

Prints stage transitions and the latest notification message as the job
progresses. Exit codes:

    0    job reached a terminal state with no error
    1    job reported a terminal error
    2    timeout (``--max-wait`` exceeded) or ``ROBOFLOW_API_KEY`` missing
    3    poller/API error (repeated failures talking to the API)
    130  interrupted (Ctrl-C)

Exit codes 1 and 3 are deliberately distinct so automation can tell "the job
failed" (1) from "the poller could not reach the API" (3).

Implementation uses inference_cli's API helpers (no raw HTTP).
"""

import argparse
import os
import sys
import time
from datetime import datetime
from typing import Any

from inference_cli.lib.roboflow_cloud.batch_processing.api_operations import (
    get_batch_job_metadata,
)
from inference_cli.lib.roboflow_cloud.common import get_workspace

# Smallest poll interval we allow, so a fat-fingered --interval can't hammer the
# API in a tight loop.
MIN_INTERVAL = 5.0
# Consecutive API failures tolerated (with backoff) before we give up polling.
MAX_CONSECUTIVE_ERRORS = 5


def _summarize_notification(notification: Any) -> str:
    """Extract a human-readable string from a notification dict or object.

    Args:
        notification: Notification payload from job metadata; expected to be a
            dict with ``message`` / ``type`` keys, or any object coercible to
            ``str``. ``None`` and falsy values yield an empty string.

    Returns:
        Notification message, type, or stringified form; empty string when
        nothing usable is available.
    """
    if isinstance(notification, dict):
        return notification.get("message") or notification.get("type") or ""
    return str(notification) if notification else ""


def _output_batches(notification: Any) -> list[Any]:
    """Extract the ``resultsBatches`` list from a notification dict.

    Args:
        notification: Notification payload from job metadata; only ``dict``
            inputs are inspected, anything else returns an empty list.

    Returns:
        List of result-batch identifiers, or an empty list when the field is
        absent or the input is not a dict.
    """
    if isinstance(notification, dict):
        return notification.get("resultsBatches", []) or []
    return []


def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    """Parse and validate CLI arguments.

    Args:
        argv: Argument list to parse; defaults to ``sys.argv[1:]``.

    Returns:
        Parsed namespace. Exits (via ``parser.error``) when ``--interval`` or
        ``--max-wait`` is not strictly positive.
    """
    parser = argparse.ArgumentParser(
        description="Poll a Roboflow Batch Processing job until terminal."
    )
    parser.add_argument("job_id", help="Job identifier returned at submission time.")
    parser.add_argument(
        "--interval",
        type=float,
        default=20.0,
        help=f"Seconds between polls (default: 20, floor: {MIN_INTERVAL:g}).",
    )
    parser.add_argument(
        "--max-wait",
        type=float,
        default=3600.0,
        help="Give up after this many seconds (default: 3600).",
    )
    args = parser.parse_args(argv)

    if args.interval <= 0:
        parser.error("--interval must be greater than 0")
    if args.max_wait <= 0:
        parser.error("--max-wait must be greater than 0")
    if args.interval < MIN_INTERVAL:
        print(
            f"--interval {args.interval:g}s is below the {MIN_INTERVAL:g}s floor; "
            f"using {MIN_INTERVAL:g}s.",
            file=sys.stderr,
        )
        args.interval = MIN_INTERVAL

    return args


def main(argv: list[str] | None = None) -> int:
    """CLI entry point: parse args, poll job until terminal, return exit code.

    Args:
        argv: Argument list to parse; defaults to ``sys.argv[1:]``. Reads
            ``ROBOFLOW_API_KEY`` from the environment.

    Returns:
        Process exit code (see the module docstring for the full table).
    """
    args = _parse_args(argv)

    api_key = os.environ.get("ROBOFLOW_API_KEY")
    if not api_key:
        print("ROBOFLOW_API_KEY is not set.", file=sys.stderr)
        return 2

    try:
        workspace = get_workspace(api_key=api_key)
    except Exception as exc:  # noqa: BLE001 - surface any client/network failure
        print(f"Could not resolve workspace: {exc}", file=sys.stderr)
        return 3
    print(f"workspace={workspace} job_id={args.job_id} interval={args.interval}s")

    start = time.monotonic()
    last_state = None
    consecutive_errors = 0
    while True:
        try:
            md = get_batch_job_metadata(
                workspace=workspace, job_id=args.job_id, api_key=api_key
            )
        except Exception as exc:  # noqa: BLE001 - transient API/network failures
            consecutive_errors += 1
            if consecutive_errors >= MAX_CONSECUTIVE_ERRORS:
                print(
                    f"Giving up after {consecutive_errors} consecutive poll "
                    f"failures. Last error: {exc}",
                    file=sys.stderr,
                )
                return 3
            print(
                f"Poll failed ({consecutive_errors}/{MAX_CONSECUTIVE_ERRORS}): "
                f"{exc}. Retrying in {args.interval:g}s.",
                file=sys.stderr,
                flush=True,
            )
            if time.monotonic() - start > args.max_wait:
                print(
                    f"Gave up after {args.max_wait}s without reaching terminal "
                    "state.",
                    file=sys.stderr,
                )
                return 2
            time.sleep(args.interval)
            continue

        consecutive_errors = 0
        notif_msg = _summarize_notification(md.last_notification)
        state = (md.current_stage, md.is_terminal, md.error, notif_msg)

        if state != last_state:
            ts = datetime.now().strftime("%H:%M:%S")
            print(
                f"[{ts}] stage={md.current_stage} "
                f"terminal={md.is_terminal} error={md.error} | {notif_msg}",
                flush=True,
            )
            last_state = state

        if md.is_terminal:
            outputs = _output_batches(md.last_notification)
            print(f"output_batches={outputs}", flush=True)
            return 1 if md.error else 0

        if time.monotonic() - start > args.max_wait:
            print(
                f"Gave up after {args.max_wait}s without reaching terminal state.",
                file=sys.stderr,
            )
            return 2

        time.sleep(args.interval)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("Interrupted.", file=sys.stderr)
        sys.exit(130)
