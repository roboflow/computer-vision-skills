"""Tests for promote_engine_sync.py. Run: python3 -m unittest discover -s .github/scripts"""

from __future__ import annotations

import io
import json
import unittest
import urllib.error
from unittest import mock

import promote_engine_sync as promotion


class PromoteEngineSyncTest(unittest.TestCase):
    def test_versions_compare_numerically(self) -> None:
        self.assertTrue(promotion.is_served("0.10.0", "0.9.3"))
        self.assertTrue(promotion.is_served("0.5.0", "0.5.0"))
        self.assertFalse(promotion.is_served("0.2.1", "0.5.0"))

    def test_promotes_only_drafts_production_can_serve(self) -> None:
        calls: list[tuple[str, ...]] = []
        targets = {"workflow-evals/engine-v0.5.0": "0.5.0", "workflow-evals/engine-v0.6.0": "0.6.0"}
        pulls = [
            {"number": 7, "headRefName": "workflow-evals/engine-v0.5.0"},
            {"number": 8, "headRefName": "workflow-evals/engine-v0.6.0"},
        ]

        promoted = promotion.promote(
            "roboflow/computer-vision-skills",
            pulls,
            "0.5.2",
            read_target=lambda _repository, branch: targets[branch],
            run_gh=lambda *args: calls.append(args) or "",
        )

        self.assertEqual(promoted, [7])
        self.assertEqual(calls[0], ("pr", "ready", "7", "--repo", "roboflow/computer-vision-skills"))
        self.assertEqual(calls[1][:3], ("pr", "comment", "7"))
        self.assertEqual(len(calls), 2)

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

    def test_without_credentials_nothing_is_promoted(self) -> None:
        env = {"GITHUB_REPOSITORY": "roboflow/computer-vision-skills"}
        with mock.patch.dict(promotion.os.environ, env, clear=True), mock.patch.object(
            promotion, "draft_sync_pull_requests", return_value=[{"number": 1, "headRefName": "b"}]
        ), mock.patch.object(promotion, "promote") as promote:
            self.assertEqual(promotion.main(), 0)
        promote.assert_not_called()


if __name__ == "__main__":
    unittest.main()
