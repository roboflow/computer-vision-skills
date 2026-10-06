"""Tests for promote_engine_sync.py. Run: python3 -m unittest discover -s .github/scripts"""

from __future__ import annotations

import io
import json
import subprocess
import unittest
import urllib.error
from unittest import mock

import promote_engine_sync as promotion

REPO = "roboflow/computer-vision-skills"


def pull(number: int, draft: bool = True) -> dict:
    return {"number": number, "isDraft": draft, "headRefName": f"workflow-evals/{number}"}


class PromoteEngineSyncTest(unittest.TestCase):
    def test_versions_compare_numerically(self) -> None:
        self.assertTrue(promotion.is_served("0.10.0", "0.9.3"))
        self.assertTrue(promotion.is_served("0.5.0", "0.5.0"))
        self.assertFalse(promotion.is_served("0.2.1", "0.5.0"))

    def test_only_the_newest_draft_ahead_of_main_is_a_candidate(self) -> None:
        targets = [(pull(7), "0.5.0"), (pull(8), "0.10.0"), (pull(9), "0.4.0")]
        candidates, superseded = promotion.triage(targets, merged_version="0.4.0")
        self.assertEqual([p["number"] for p, _ in candidates], [8])
        # Only main can supersede: #7 waits for the unmerged #8 instead of being closed.
        self.assertEqual([(p["number"], reason) for p, _, reason in superseded], [(9, "the default branch already ships engine 0.4.0")])

    def test_an_unmerged_newer_sync_holds_older_drafts_without_closing_them(self) -> None:
        targets = [(pull(7), "0.5.0"), (pull(8, draft=False), "0.6.0")]
        candidates, superseded = promotion.triage(targets, merged_version=None)
        self.assertEqual((candidates, superseded), ([], []))

    def test_any_unreadable_sync_pauses_the_whole_run(self) -> None:
        def read(_repository: str, branch: str) -> str:
            if branch.endswith("/8"):
                raise subprocess.CalledProcessError(1, ["gh"])
            return "0.5.0"

        self.assertIsNone(promotion.read_targets(REPO, [pull(7), pull(8, draft=False)], read))
        targets = promotion.read_targets(REPO, [pull(7)], read)
        self.assertEqual([p["number"] for p, _ in targets or []], [7])

    def test_promote_marks_ready_only_what_production_serves(self) -> None:
        calls: list[tuple[str, ...]] = []
        record = lambda *args: calls.append(args) or ""  # noqa: E731
        promoted = promotion.promote(REPO, [(pull(8), "0.6.0")], "0.5.2", run_gh=record)
        self.assertEqual((promoted, calls), ([], []))
        promoted = promotion.promote(REPO, [(pull(8), "0.6.0")], "0.6.0", run_gh=record)
        self.assertEqual(promoted, [8])
        self.assertEqual([call[:3] for call in calls], [("pr", "ready", "8"), ("pr", "comment", "8")])

    def test_superseded_drafts_are_closed_with_the_reason(self) -> None:
        calls: list[tuple[str, ...]] = []
        promotion.close_superseded(REPO, [(pull(7), "0.5.0", "another engine-sync pull request targets engine 0.6.0")], run_gh=lambda *a: calls.append(a) or "")
        self.assertEqual(calls[0][:3], ("pr", "close", "7"))
        self.assertIn("targets engine 0.6.0", calls[0][-1])

    def test_reads_the_served_version(self) -> None:
        response = io.BytesIO(json.dumps({"engine": {"version": "0.5.0"}}).encode())
        with mock.patch.object(promotion.urllib.request, "urlopen", return_value=response) as urlopen:
            version = promotion.production_version("https://api.example", "acme ws", "secret-key")
        self.assertEqual(version, "0.5.0")
        url = urlopen.call_args.args[0]
        self.assertTrue(url.startswith("https://api.example/workspaces/acme%20ws/workflow-evals/capabilities?"))

    def test_errors_never_include_the_api_key(self) -> None:
        failure = urllib.error.HTTPError("https://x?api_key=secret-key", 401, "Unauthorized", {}, None)
        with mock.patch.object(promotion.urllib.request, "urlopen", side_effect=failure):
            with self.assertRaises(RuntimeError) as raised:
                promotion.production_version("https://api.example", "acme", "secret-key")
        self.assertIn("HTTP 401", str(raised.exception))
        self.assertNotIn("secret-key", str(raised.exception))
        self.assertIsNone(raised.exception.__cause__)

    def test_without_credentials_superseded_drafts_close_but_nothing_is_promoted(self) -> None:
        env = {"GITHUB_REPOSITORY": REPO}
        targets = {"workflow-evals/7": "0.5.0", "workflow-evals/8": "0.6.0", "main": "0.5.0"}
        with mock.patch.dict(promotion.os.environ, env, clear=True), mock.patch.object(
            promotion, "open_sync_pull_requests", return_value=[pull(7), pull(8)]
        ), mock.patch.object(
            promotion, "target_version", side_effect=lambda _repo, ref: targets[ref]
        ), mock.patch.object(promotion, "close_superseded") as close, mock.patch.object(
            promotion, "promote"
        ) as promote:
            self.assertEqual(promotion.main(), 0)
        self.assertEqual([p["number"] for p, _, _ in close.call_args.args[1]], [7])
        promote.assert_not_called()


if __name__ == "__main__":
    unittest.main()
