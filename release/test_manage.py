"""Offline integration tests: python3 -m unittest discover -s release."""

import hashlib
import json
import subprocess
import tempfile
import unittest
import zipfile
from pathlib import Path

from manage import MANIFESTS, build, bump, check, check_tag, git, prepare


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        git(self.root, "init", "-q")
        git(self.root, "config", "user.name", "Release test")
        git(self.root, "config", "user.email", "test@example.com")
        for path in MANIFESTS:
            self.write(path, json.dumps({"version": "1.0.2", "name": "roboflow"}))
        for path in ("skills/example/SKILL.md", ".mcp.json", ".agents/plugins/marketplace.json", "LICENSE"):
            self.write(path, "original\n")
        self.write("chatgpt/plugin/plugin.json", '{"version": "1.0.3"}')
        self.write(".gitignore", "release/build/\n")
        self.commit()
        self.base = git(self.root, "rev-parse", "HEAD").decode().strip()

    def write(self, path, content):
        destination = self.root / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(content, encoding="utf-8")

    def commit(self):
        git(self.root, "add", ".")
        git(self.root, "commit", "-qm", "fixture")

    def test_docs_and_chatgpt_changes_do_not_require_native_release(self):
        self.write("README.md", "new docs")
        self.write("chatgpt/plugin/plugin.json", '{"version": "1.0.4"}')
        self.assertEqual(check(self.root, self.base), "1.0.2")

    def test_shipped_changes_pass_pr_checks_without_manual_bump(self):
        for path in ("skills/example/SKILL.md", "skills/new/SKILL.md", ".mcp.json",
                     ".agents/plugins/marketplace.json", MANIFESTS[0]):
            with self.subTest(path=path):
                git(self.root, "reset", "--hard", self.base)
                git(self.root, "clean", "-fd")
                if path == MANIFESTS[0]:
                    self.write(path, '{"version": "1.0.2", "name": "changed"}')
                else:
                    self.write(path, "changed")
                self.assertEqual(check(self.root, self.base), "1.0.2")

    def test_deleted_skill_passes_pr_checks_without_manual_bump(self):
        (self.root / "skills/example/SKILL.md").unlink()
        self.assertEqual(check(self.root, self.base), "1.0.2")

    def test_first_release_commits_both_versions_and_builds_from_tag(self):
        tag = prepare(self.root)
        self.assertEqual(tag, "plugin-v1.0.3")
        self.assertEqual(check(self.root), "1.0.3")
        self.assertEqual(git(self.root, "status", "--porcelain"), b"")
        self.assertEqual(git(self.root, "diff", "--name-only", self.base).decode().splitlines(),
                         sorted(MANIFESTS))
        self.assertEqual(git(self.root, "rev-parse", tag), git(self.root, "rev-parse", "HEAD"))
        archive = build(self.root, tag)
        with zipfile.ZipFile(archive) as bundle:
            for path in MANIFESTS:
                self.assertEqual(json.loads(bundle.read(path))["version"], "1.0.3")

    def test_retry_reuses_tag_and_commit_after_artifact_failure(self):
        tag = prepare(self.root)
        commit = git(self.root, "rev-parse", "HEAD")
        original = build(self.root, tag).read_bytes()
        self.assertEqual(prepare(self.root), tag)
        self.assertEqual(git(self.root, "rev-parse", "HEAD"), commit)
        self.assertEqual(build(self.root, tag).read_bytes(), original)

    def test_docs_and_chatgpt_merges_do_not_bump_native_version(self):
        tag = prepare(self.root)
        self.write("README.md", "updated docs")
        self.write("chatgpt/plugin/plugin.json", '{"version": "1.0.4"}')
        self.commit()
        commit = git(self.root, "rev-parse", "HEAD")
        self.assertEqual(prepare(self.root), tag)
        self.assertEqual(check(self.root), "1.0.3")
        self.assertEqual(git(self.root, "rev-parse", "HEAD"), commit)

    def test_each_shipped_change_gets_next_patch(self):
        prepare(self.root)
        changes = (("skills/example/SKILL.md", "changed"),
                   ("skills/new/SKILL.md", "new skill"),
                   (".mcp.json", "new connection"),
                   (".agents/plugins/marketplace.json", "new marketplace"),
                   ("LICENSE", "new license"))
        for patch, (path, text) in enumerate(changes, start=4):
            with self.subTest(path=path):
                self.write(path, text)
                self.commit()
                tag = prepare(self.root)
                self.assertEqual(tag, f"plugin-v1.0.{patch}")
                self.assertEqual(check(self.root), f"1.0.{patch}")
                build(self.root, tag)
        (self.root / "skills/new/SKILL.md").unlink()
        self.commit()
        self.assertEqual(prepare(self.root), "plugin-v1.0.9")

    def test_explicit_major_or_minor_bump_is_respected(self):
        prepare(self.root)
        bump(self.root, "2.0.0")
        self.commit()
        commit = git(self.root, "rev-parse", "HEAD")
        self.assertEqual(prepare(self.root), "plugin-v2.0.0")
        self.assertEqual(git(self.root, "rev-parse", "HEAD"), commit)

    def test_dirty_checkout_is_not_committed_by_prepare(self):
        self.write("README.md", "user work")
        with self.assertRaisesRegex(ValueError, "clean checkout"):
            prepare(self.root)
        self.assertEqual(git(self.root, "rev-parse", "HEAD").decode().strip(), self.base)

    def test_atomic_push_rejects_stale_main_without_publishing_tag(self):
        with tempfile.TemporaryDirectory() as directory:
            remote = Path(directory) / "remote.git"
            subprocess.check_output(["git", "init", "--bare", "-q", str(remote)])
            git(self.root, "remote", "add", "origin", str(remote))
            git(self.root, "push", "-q", "origin", "HEAD:refs/heads/main")
            # Another merge reaches main before this runner publishes its bump.
            self.write("skills/example/SKILL.md", "concurrent merge")
            self.commit()
            other = git(self.root, "rev-parse", "HEAD").decode().strip()
            git(self.root, "push", "-q", "origin", "HEAD:refs/heads/main")
            git(self.root, "checkout", "--detach", self.base)
            tag = prepare(self.root)
            with self.assertRaises(subprocess.CalledProcessError):
                git(self.root, "push", "--atomic", "origin", "HEAD:refs/heads/main", f"refs/tags/{tag}")
            self.assertEqual(git(remote, "tag", "--list"), b"")
            self.assertEqual(git(remote, "rev-parse", "refs/heads/main").decode().strip(), other)
            # Retry follows the workflow: drop only its local tag, fetch main,
            # and prepare against the newest commit without losing that merge.
            git(self.root, "tag", "-d", tag)
            git(self.root, "fetch", "origin", "main", "--tags")
            git(self.root, "checkout", "--detach", "origin/main")
            tag = prepare(self.root)
            git(self.root, "push", "--atomic", "origin", "HEAD:refs/heads/main", f"refs/tags/{tag}")
            self.assertEqual(tag, "plugin-v1.0.3")
            self.assertEqual(git(remote, "show", f"{tag}:skills/example/SKILL.md"), b"concurrent merge")
            self.assertEqual(git(remote, "rev-parse", tag), git(remote, "rev-parse", "refs/heads/main"))

    def test_mismatch_and_decrease_fail(self):
        self.write(MANIFESTS[1], '{"version": "1.0.3"}')
        with self.assertRaisesRegex(ValueError, "versions differ"):
            check(self.root)
        for path in MANIFESTS:
            self.write(path, '{"version": "1.0.1"}')
        with self.assertRaisesRegex(ValueError, "must not decrease"):
            check(self.root, self.base)

    def test_bump_is_numeric_and_preserves_metadata(self):
        bump(self.root, "1.0.10")
        for path in MANIFESTS:
            self.assertEqual(json.loads((self.root / path).read_text()),
                             {"name": "roboflow", "version": "1.0.10"})
        self.assertEqual(json.loads((self.root / "chatgpt/plugin/plugin.json").read_text())["version"], "1.0.3")
        for invalid in ("1.0.9", "1.0.10", "v2.0.0", "01.0.0", "2.0.0-beta", "2.0", "$(echo bad)"):
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                bump(self.root, invalid)
        self.assertEqual(check(self.root), "1.0.10")

    def test_release_tag_matches_its_distribution(self):
        self.assertEqual(check_tag(self.root, "plugin-v1.0.2"), "1.0.2")
        self.assertEqual(check_tag(self.root, "chatgpt-v1.0.3"), "1.0.3")
        for tag in ("plugin-v1.0.3", "chatgpt-v1.0.2", "v1.0.2", "plugin-v1.0.2-extra"):
            with self.subTest(tag=tag), self.assertRaises(ValueError):
                check_tag(self.root, tag)

    def test_archive_contains_only_committed_plugin_files_and_valid_provenance(self):
        self.write("README.md", "not bundled")
        self.write(".gitignore", "skills/example/secret.txt\n")
        self.commit()
        self.write("skills/example/secret.txt", "ignored")
        archive = build(self.root, "plugin-v1.0.2")
        with zipfile.ZipFile(archive) as bundle:
            files = {name for name in bundle.namelist() if not name.endswith("/")}
            self.assertEqual(files, {*MANIFESTS, "skills/example/SKILL.md", ".mcp.json",
                                     ".agents/plugins/marketplace.json", "LICENSE"})
            self.assertEqual(bundle.read("skills/example/SKILL.md"), b"original\n")
        provenance = json.loads(archive.with_suffix(".provenance.json").read_text())
        self.assertEqual(provenance["package_sha256"], hashlib.sha256(archive.read_bytes()).hexdigest())
        self.assertEqual(provenance["skills_commit"], git(self.root, "rev-parse", "HEAD").decode().strip())
        self.assertEqual(provenance["package_version"], "1.0.2")
        original = archive.read_bytes()
        self.assertEqual(build(self.root, "plugin-v1.0.2").read_bytes(), original)

    def test_dirty_or_untracked_package_files_block_archive(self):
        self.write("skills/example/SKILL.md", "dirty")
        with self.assertRaisesRegex(ValueError, "clean checkout"):
            build(self.root, "plugin-v1.0.2")
        git(self.root, "reset", "--hard", self.base)
        self.write("skills/example/new.txt", "untracked")
        with self.assertRaisesRegex(ValueError, "clean checkout"):
            build(self.root, "plugin-v1.0.2")

    def test_unknown_base_fails_closed(self):
        with self.assertRaises(subprocess.CalledProcessError):
            check(self.root, "missing-ref")


if __name__ == "__main__":
    unittest.main()
