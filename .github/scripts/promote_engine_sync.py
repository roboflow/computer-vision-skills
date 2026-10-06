"""Mark engine-sync pull requests ready once production serves their Workflow Evals engine.

A sync pull request regenerates skills/roboflow-workflow-evals/reference for one engine
release. Merging it before production runs that engine would teach agents vocabulary the API
rejects, so it stays a draft until GET /workflow-evals/capabilities reports that version.

Environment: GITHUB_REPOSITORY, GH_TOKEN, ROBOFLOW_API_KEY, ROBOFLOW_WORKSPACE, and optionally
ROBOFLOW_API_URL. Without the Roboflow variables the script only reports what it would check.
"""

from __future__ import annotations

import base64
import json
import os
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from typing import Callable

SYNC_LABEL = "engine-sync"
REFERENCE_MANIFEST = "skills/roboflow-workflow-evals/reference/manifest.json"
DEFAULT_API_URL = "https://api.roboflow.com"


def version_key(version: str) -> tuple[int, ...]:
    return tuple(int(part) for part in version.split("."))


def is_served(production_version: str, target_version: str) -> bool:
    return version_key(production_version) >= version_key(target_version)


def gh(*args: str) -> str:
    return subprocess.run(["gh", *args], check=True, capture_output=True, text=True).stdout


def draft_sync_pull_requests(repository: str) -> list[dict]:
    pulls = json.loads(
        gh(
            "pr", "list", "--repo", repository, "--label", SYNC_LABEL, "--state", "open",
            "--json", "number,isDraft,headRefName",
        )
    )
    return [pull for pull in pulls if pull["isDraft"]]


def target_version(repository: str, branch: str) -> str:
    ref = urllib.parse.quote(branch, safe="")
    encoded = gh("api", f"repos/{repository}/contents/{REFERENCE_MANIFEST}?ref={ref}", "--jq", ".content")
    return json.loads(base64.b64decode(encoded))["engineVersion"]


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


def promote(
    repository: str,
    pulls: list[dict],
    served: str,
    read_target: Callable[[str, str], str] = target_version,
    run_gh: Callable[..., str] = gh,
) -> list[int]:
    promoted = []
    for pull in pulls:
        number = str(pull["number"])
        target = read_target(repository, pull["headRefName"])
        if not is_served(served, target):
            print(f"#{number} waits: production serves engine {served}, the PR targets {target}.")
            continue
        run_gh("pr", "ready", number, "--repo", repository)
        run_gh(
            "pr", "comment", number, "--repo", repository, "--body",
            f"Production serves Workflow Evals engine {served}, which covers {target}. "
            "Marked ready for review.",
        )
        promoted.append(pull["number"])
    return promoted


def main() -> int:
    repository = os.environ["GITHUB_REPOSITORY"]
    pulls = draft_sync_pull_requests(repository)
    if not pulls:
        print("No draft engine-sync pull requests.")
        return 0
    api_key = os.environ.get("ROBOFLOW_API_KEY", "")
    workspace = os.environ.get("ROBOFLOW_WORKSPACE", "")
    if not api_key or not workspace:
        print("::warning::Set ROBOFLOW_API_KEY and ROBOFLOW_WORKSPACE to promote engine-sync drafts.")
        return 0
    api_url = os.environ.get("ROBOFLOW_API_URL") or DEFAULT_API_URL
    served = production_version(api_url, workspace, api_key)
    promoted = promote(repository, pulls, served)
    print(f"Production serves engine {served}; promoted {len(promoted)} of {len(pulls)} drafts.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
