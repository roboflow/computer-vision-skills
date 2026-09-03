#!/usr/bin/env python3
"""Poll a Roboflow Batch Processing job until it reaches a terminal state.

The script is directly executable (shebang + exec bit set in git). Invoke as:

    ./poll_batch_job.py <job_id> [--interval SECONDS] [--max-wait SECONDS]

Or with an explicit interpreter:

    python poll_batch_job.py <job_id> [--interval SECONDS] [--max-wait SECONDS]

Requires:
    export ROBOFLOW_API_KEY=...
    pip install inference-cli

Prints stage transitions and the latest notification message as the job
progresses. Exits 0 on success, 1 on terminal error, 2 on timeout / missing
API key, 130 on KeyboardInterrupt.

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


def main() -> int:
    """CLI entry point: parse args, poll job until terminal, return exit code.

    Args:
        None. Reads ``sys.argv`` via ``argparse`` and ``ROBOFLOW_API_KEY`` from
        the environment.

    Returns:
        Process exit code: ``0`` on successful terminal state, ``1`` on
        terminal error reported by the job, ``2`` on timeout or missing
        ``ROBOFLOW_API_KEY``.
    """
    parser = argparse.ArgumentParser(
        description="Poll a Roboflow Batch Processing job until terminal."
    )
    parser.add_argument("job_id", help="Job identifier returned at submission time.")
    parser.add_argument(
        "--interval",
        type=float,
        default=20.0,
        help="Seconds between polls (default: 20).",
    )
    parser.add_argument(
        "--max-wait",
        type=float,
        default=3600.0,
        help="Give up after this many seconds (default: 3600).",
    )
    args = parser.parse_args()

    api_key = os.environ.get("ROBOFLOW_API_KEY")
    if not api_key:
        print("ROBOFLOW_API_KEY is not set.", file=sys.stderr)
        return 2

    workspace = get_workspace(api_key=api_key)
    print(f"workspace={workspace} job_id={args.job_id} interval={args.interval}s")

    start = time.monotonic()
    last_state = None
    while True:
        md = get_batch_job_metadata(
            workspace=workspace, job_id=args.job_id, api_key=api_key
        )
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
