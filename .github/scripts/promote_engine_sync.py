"""Mark the engine-sync pull request ready once production serves its Workflow Evals engine.

An engine-sync pull request regenerates skills/roboflow-workflow-evals/reference for one engine
release. Merging it before production runs that engine would teach agents vocabulary the API
rejects, so it stays a draft until GET /workflow-evals/capabilities reports that version.

Only the newest sync can be promoted. A draft whose engine is not newer than every other open
engine-sync pull request and than the reference already on the default branch is superseded:
merging it would roll the reference back, so it is closed with a comment instead.

Environment: GITHUB_REPOSITORY, GH_TOKEN, ROBOFLOW_API_KEY, ROBOFLOW_WORKSPACE, and optionally
ROBOFLOW_API_URL. Without the Roboflow variables nothing is promoted.
"""

from __future__ import annotations

import base64
import binascii
import json
import os
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from typing import Callable, Optional

SYNC_LABEL = "engine-sync"
REFERENCE_MANIFEST = "skills/roboflow-workflow-evals/reference/manifest.json"
DEFAULT_API_URL = "https://api.roboflow.com"
READ_ERRORS = (subprocess.CalledProcessError, KeyError, ValueError, binascii.Error)


def version_key(version: str) -> tuple[int, ...]:
    return tuple(int(part) for part in version.split("."))


def is_served(production_version: str, target_version: str) -> bool:
    return version_key(production_version) >= version_key(target_version)


def gh(*args: str) -> str:
    return subprocess.run(["gh", *args], check=True, capture_output=True, text=True).stdout


def open_sync_pull_requests(repository: str) -> list[dict]:
    return json.loads(
        gh(
            "pr", "list", "--repo", repository, "--label", SYNC_LABEL, "--state", "open",
            "--json", "number,isDraft,headRefName",
        )
    )


def target_version(repository: str, ref: str) -> str:
    """Engine version of the reference snapshot at a branch or ref."""
    quoted = urllib.parse.quote(ref, safe="")
    encoded = gh("api", f"repos/{repository}/contents/{REFERENCE_MANIFEST}?ref={quoted}", "--jq", ".content")
    version = json.loads(base64.b64decode(encoded))["engineVersion"]
    version_key(version)
    return version


def production_version(api_url: str, workspace: str, api_key: str) -> str:
    """Read the engine version production serves. Errors never include the key-bearing URL."""
    path = f"/workspaces/{urllib.parse.quote(workspace, safe='')}/workflow-evals/capabilities"
    url = f"{api_url}{path}?{urllib.parse.urlencode({'api_key': api_key})}"
    try:
        with urllib.request.urlopen(url, timeout=30) as response:
            return json.load(response)["engine"]["version"]
    except urllib.error.HTTPError as error:
        raise RuntimeError(f"GET {path} failed with HTTP {error.code}") from None
    except (urllib.error.URLError, TimeoutError, KeyError, ValueError) as error:
        raise RuntimeError(f"GET {path} failed: {type(error).__name__}") from None


def read_targets(
    repository: str, pulls: list[dict], read_target: Callable[[str, str], str]
) -> list[tuple[dict, str]]:
    targets = []
    for pull in pulls:
        try:
            targets.append((pull, read_target(repository, pull["headRefName"])))
        except READ_ERRORS as error:
            print(f"::warning::Skipped #{pull['number']}: could not read its engine version ({type(error).__name__}).")
    return targets


def triage(
    targets: list[tuple[dict, str]], merged_version: Optional[str]
) -> tuple[list[tuple[dict, str]], list[tuple[dict, str, str]]]:
    """Split drafts into the one that may be promoted and the superseded ones."""
    if not targets:
        return [], []
    newest = max((target for _, target in targets), key=version_key)
    candidates, superseded = [], []
    for pull, target in targets:
        if not pull["isDraft"]:
            continue
        if merged_version and version_key(target) <= version_key(merged_version):
            superseded.append((pull, target, f"the default branch already ships engine {merged_version}"))
        elif version_key(target) < version_key(newest):
            superseded.append((pull, target, f"another engine-sync pull request targets engine {newest}"))
        else:
            candidates.append((pull, target))
    return candidates, superseded


def close_superseded(repository: str, superseded: list[tuple[dict, str, str]], run_gh: Callable[..., str] = gh) -> None:
    for pull, target, reason in superseded:
        run_gh(
            "pr", "close", str(pull["number"]), "--repo", repository, "--comment",
            f"Closing: this syncs engine {target}, but {reason}. Merging it would roll the reference back.",
        )


def promote(
    repository: str, candidates: list[tuple[dict, str]], served: str, run_gh: Callable[..., str] = gh
) -> list[int]:
    promoted = []
    for pull, target in candidates:
        number = str(pull["number"])
        if not is_served(served, target):
            print(f"#{number} waits: production serves engine {served}, the PR targets {target}.")
            continue
        run_gh("pr", "ready", number, "--repo", repository)
        run_gh(
            "pr", "comment", number, "--repo", repository, "--body",
            f"Production serves Workflow Evals engine {served}, which covers {target}. Marked ready for review.",
        )
        promoted.append(pull["number"])
    return promoted


def main() -> int:
    repository = os.environ["GITHUB_REPOSITORY"]
    pulls = open_sync_pull_requests(repository)
    if not any(pull["isDraft"] for pull in pulls):
        print("No draft engine-sync pull requests.")
        return 0
    targets = read_targets(repository, pulls, target_version)
    try:
        merged = target_version(repository, os.environ.get("DEFAULT_BRANCH") or "main")
    except READ_ERRORS:
        merged = None
    candidates, superseded = triage(targets, merged)
    close_superseded(repository, superseded)
    if not candidates:
        return 0
    api_key = os.environ.get("ROBOFLOW_API_KEY", "")
    workspace = os.environ.get("ROBOFLOW_WORKSPACE", "")
    if not api_key or not workspace:
        print("::warning::Set ROBOFLOW_API_KEY and ROBOFLOW_WORKSPACE to promote engine-sync drafts.")
        return 0
    served = production_version(os.environ.get("ROBOFLOW_API_URL") or DEFAULT_API_URL, workspace, api_key)
    promoted = promote(repository, candidates, served)
    print(f"Production serves engine {served}; promoted {len(promoted)} draft(s).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
