#!/usr/bin/env python3
"""Run lightweight Roboflow skill evals.

The runner is dependency-free by design. It invokes an agent, captures the
answer, and scores it against deterministic include/exclude checks.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shlex
import shutil
import subprocess
import tempfile
import textwrap
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[2]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--suite", default="smoke", help="Eval suite name from evals/cases/<suite>.json")
    parser.add_argument("--agent", default="claude", choices=["claude", "codex"], help="Agent command to invoke")
    parser.add_argument("--base", help="Optional base git ref for branch-vs-branch comparison")
    parser.add_argument("--candidate", help="Optional candidate git ref for branch-vs-branch comparison")
    parser.add_argument("--output", help="Optional JSONL output path for a single-ref run")
    parser.add_argument("--timeout", type=int, default=180, help="Per-case timeout in seconds")
    parser.add_argument("--list", action="store_true", help="List eval cases and exit")
    parser.add_argument("--dry-run", action="store_true", help="Print planned agent commands without running them")
    parser.add_argument("--keep-worktrees", action="store_true", help="Do not delete temporary compare worktrees")
    return parser.parse_args()


def load_suite(repo: Path, suite_name: str) -> dict[str, Any]:
    suite_path = repo / "evals" / "cases" / f"{suite_name}.json"
    if not suite_path.exists():
        raise SystemExit(f"Eval suite not found: {suite_path}")
    with suite_path.open("r", encoding="utf-8") as handle:
        data = json.load(handle)
    if "cases" not in data or not isinstance(data["cases"], list):
        raise SystemExit(f"Eval suite must contain a cases array: {suite_path}")
    return data


def skill_dirs(repo: Path) -> list[Path]:
    skills_root = repo / "skills"
    if skills_root.exists():
        return sorted(path for path in skills_root.iterdir() if (path / "SKILL.md").exists())
    return sorted(path for path in repo.iterdir() if path.is_dir() and (path / "SKILL.md").exists())


def validate_frontmatter(skill_file: Path) -> list[str]:
    failures: list[str] = []
    lines = skill_file.read_text(encoding="utf-8").splitlines()
    if not lines or lines[0].strip() != "---":
        return [f"{skill_file}: missing opening frontmatter fence"]
    closing = None
    for index, line in enumerate(lines[1:], start=2):
        if line.strip() == "---":
            closing = index
            break
    if closing is None:
        return [f"{skill_file}: missing closing frontmatter fence"]
    frontmatter = "\n".join(lines[1 : closing - 1])
    if not re.search(r"^name:\s+\S+", frontmatter, re.MULTILINE):
        failures.append(f"{skill_file}: missing name")
    if not re.search(r"^description:\s+.+", frontmatter, re.MULTILINE):
        failures.append(f"{skill_file}: missing description")
    return failures


def validate_repo(repo: Path, agent: str) -> list[str]:
    failures: list[str] = []

    dirs = skill_dirs(repo)
    if not dirs:
        failures.append("No skill directories found")
    for directory in dirs:
        failures.extend(validate_frontmatter(directory / "SKILL.md"))

    json_paths = [
        repo / ".mcp.json",
        repo / ".claude-plugin" / "plugin.json",
        repo / ".codex-plugin" / "plugin.json",
    ]
    for path in json_paths:
        if path.exists():
            try:
                json.loads(path.read_text(encoding="utf-8"))
            except json.JSONDecodeError as exc:
                failures.append(f"{path}: invalid JSON: {exc}")

    if agent == "claude" and not (repo / ".claude-plugin" / "plugin.json").exists():
        failures.append("Claude plugin manifest not found at .claude-plugin/plugin.json")
    if agent == "codex" and not (repo / ".codex-plugin" / "plugin.json").exists():
        failures.append("Codex plugin manifest not found at .codex-plugin/plugin.json")

    return failures


def prompt_for_case(repo: Path, case: dict[str, Any]) -> str:
    skills_hint = "./skills" if (repo / "skills").exists() else "the top-level skill directories"
    return textwrap.dedent(
        f"""
        You are evaluating the Roboflow agent skills in this repository.

        Use the Roboflow guidance from {skills_hint}. Answer the user directly.
        Prefer Roboflow MCP tools when they are available, but do not call live
        Roboflow services for this eval. Recommend the tool or workflow the user
        should use.

        User request:
        {case["prompt"]}
        """
    ).strip()


def claude_command(repo: Path, prompt: str) -> list[str]:
    command = [
        "claude",
        "--print",
        "--output-format",
        "json",
        "--permission-mode",
        "dontAsk",
    ]
    if (repo / ".claude-plugin" / "plugin.json").exists():
        command.extend(["--plugin-dir", str(repo)])
    command.append(prompt)
    return command


def codex_command(repo: Path, prompt: str) -> list[str]:
    return ["codex", "exec", "-C", str(repo), prompt]


def planned_command(agent: str, repo: Path, prompt: str) -> list[str]:
    if agent == "claude":
        return claude_command(repo, prompt)
    if agent == "codex":
        return codex_command(repo, prompt)
    raise AssertionError(agent)


def command_preview(command: list[str]) -> str:
    if not command:
        return ""
    preview = command[:-1] + ["<prompt>"]
    return " ".join(shlex.quote(part) for part in preview)


def parse_agent_output(agent: str, stdout: str) -> str:
    if agent == "claude":
        try:
            payload = json.loads(stdout)
        except json.JSONDecodeError:
            return stdout
        for key in ("result", "response", "content", "text"):
            value = payload.get(key)
            if isinstance(value, str):
                return value
        return json.dumps(payload, indent=2, sort_keys=True)
    return stdout


def run_agent(agent: str, repo: Path, prompt: str, timeout: int) -> tuple[str, list[str], float]:
    command = planned_command(agent, repo, prompt)
    env = os.environ.copy()
    env.setdefault("ROBOFLOW_API_KEY", "eval-placeholder")

    start = time.monotonic()
    try:
        completed = subprocess.run(
            command,
            cwd=repo,
            env=env,
            text=True,
            capture_output=True,
            timeout=timeout,
            check=False,
        )
    except FileNotFoundError:
        return "", [f"Agent command not found: {command[0]}"], time.monotonic() - start
    except subprocess.TimeoutExpired:
        return "", [f"Agent timed out after {timeout}s"], time.monotonic() - start

    elapsed = time.monotonic() - start
    output = parse_agent_output(agent, completed.stdout)
    failures: list[str] = []
    if completed.returncode != 0:
        stderr = completed.stderr.strip()
        failures.append(f"Agent exited with code {completed.returncode}: {stderr[:800]}")
    return output, failures, elapsed


def contains(text: str, phrase: str) -> bool:
    return phrase.lower() in text.lower()


def score_case(case: dict[str, Any], output: str, agent_failures: list[str]) -> dict[str, Any]:
    expected = case.get("expected", {})
    failures = list(agent_failures)

    for phrase in expected.get("must_include", []):
        if not contains(output, phrase):
            failures.append(f"missing required phrase: {phrase}")

    for group in expected.get("must_include_any", []):
        if not any(contains(output, phrase) for phrase in group):
            failures.append(f"missing one of: {', '.join(group)}")

    for phrase in expected.get("must_not_include", []):
        if contains(output, phrase):
            failures.append(f"forbidden phrase present: {phrase}")

    for pattern in expected.get("must_include_regex", []):
        if not re.search(pattern, output, flags=re.IGNORECASE | re.MULTILINE):
            failures.append(f"missing required regex: {pattern}")

    for pattern in expected.get("must_not_include_regex", []):
        if re.search(pattern, output, flags=re.IGNORECASE | re.MULTILINE):
            failures.append(f"forbidden regex present: {pattern}")

    return {
        "id": case["id"],
        "passed": not failures,
        "failures": failures,
        "output": output,
    }


def default_output_path(repo: Path, agent: str, suite: str, label: str) -> Path:
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    runs_dir = repo / "evals" / "runs"
    runs_dir.mkdir(parents=True, exist_ok=True)
    safe_label = re.sub(r"[^A-Za-z0-9_.-]+", "-", label)
    return runs_dir / f"{timestamp}-{suite}-{agent}-{safe_label}.jsonl"


def run_suite(
    repo: Path,
    suite_name: str,
    agent: str,
    timeout: int,
    output_path: Path | None,
    dry_run: bool,
    label: str,
) -> dict[str, Any]:
    suite = load_suite(REPO_ROOT, suite_name)
    cases = suite["cases"]

    static_failures = validate_repo(repo, agent)
    if static_failures:
        print(f"Static validation failures for {label}:")
        for failure in static_failures:
            print(f"  - {failure}")
        if not dry_run:
            return {
                "label": label,
                "passed": 0,
                "total": len(cases),
                "results": [
                    {
                        "id": case["id"],
                        "passed": False,
                        "failures": static_failures,
                        "output": "",
                    }
                    for case in cases
                ],
            }

    if output_path is None and not dry_run:
        output_path = default_output_path(REPO_ROOT, agent, suite_name, label)

    results: list[dict[str, Any]] = []
    if output_path is not None and not dry_run:
        output_path.parent.mkdir(parents=True, exist_ok=True)

    output_handle = output_path.open("w", encoding="utf-8") if output_path and not dry_run else None
    try:
        for case in cases:
            prompt = prompt_for_case(repo, case)
            command = planned_command(agent, repo, prompt)
            if dry_run:
                print(f"[{label}] {case['id']}: {command_preview(command)}")
                continue

            print(f"[{label}] running {case['id']}")
            agent_output, agent_failures, elapsed = run_agent(agent, repo, prompt, timeout)
            result = score_case(case, agent_output, agent_failures)
            result.update(
                {
                    "agent": agent,
                    "suite": suite_name,
                    "label": label,
                    "duration_seconds": round(elapsed, 3),
                }
            )
            results.append(result)
            if output_handle:
                output_handle.write(json.dumps(result, sort_keys=True) + "\n")
                output_handle.flush()
    finally:
        if output_handle:
            output_handle.close()

    passed = sum(1 for result in results if result.get("passed"))
    if not dry_run:
        print(f"[{label}] passed {passed}/{len(results)} cases")
        for result in results:
            if not result.get("passed"):
                print(f"  FAIL {result['id']}")
                for failure in result["failures"]:
                    print(f"    - {failure}")
        if output_path:
            print(f"[{label}] wrote {output_path}")

    return {"label": label, "passed": passed, "total": len(results), "results": results}


def list_cases(repo: Path, suite_name: str) -> None:
    suite = load_suite(repo, suite_name)
    print(f"{suite['name']}: {suite.get('description', '')}")
    for case in suite["cases"]:
        print(f"- {case['id']}: {case['prompt']}")


def add_worktree(root: Path, ref: str, parent: Path, label: str) -> Path:
    safe_ref = re.sub(r"[^A-Za-z0-9_.-]+", "-", ref)
    target = parent / f"{label}-{safe_ref}"
    subprocess.run(
        ["git", "-C", str(root), "worktree", "add", "--detach", str(target), ref],
        check=True,
        text=True,
    )
    return target


def remove_worktree(root: Path, path: Path) -> None:
    subprocess.run(
        ["git", "-C", str(root), "worktree", "remove", "--force", str(path)],
        check=False,
        text=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def compare_results(base: dict[str, Any], candidate: dict[str, Any]) -> int:
    base_by_id = {result["id"]: result for result in base["results"]}
    candidate_by_id = {result["id"]: result for result in candidate["results"]}

    improved = []
    regressed = []
    for case_id, candidate_result in candidate_by_id.items():
        base_result = base_by_id.get(case_id)
        if not base_result:
            continue
        if not base_result["passed"] and candidate_result["passed"]:
            improved.append(case_id)
        if base_result["passed"] and not candidate_result["passed"]:
            regressed.append(case_id)

    print("\nComparison")
    print(f"  base:      {base['passed']}/{base['total']} passed ({base['label']})")
    print(f"  candidate: {candidate['passed']}/{candidate['total']} passed ({candidate['label']})")
    if improved:
        print("  improved:")
        for case_id in improved:
            print(f"    - {case_id}")
    if regressed:
        print("  regressed:")
        for case_id in regressed:
            print(f"    - {case_id}")

    return 1 if regressed or candidate["passed"] < base["passed"] else 0


def main() -> int:
    args = parse_args()

    if args.list:
        list_cases(REPO_ROOT, args.suite)
        return 0

    if bool(args.base) != bool(args.candidate):
        raise SystemExit("--base and --candidate must be provided together")

    if args.base and args.candidate:
        tmp_path = Path(tempfile.mkdtemp(prefix="roboflow-evals-"))
        base_path = add_worktree(REPO_ROOT, args.base, tmp_path, "base")
        candidate_path = add_worktree(REPO_ROOT, args.candidate, tmp_path, "candidate")
        try:
            base = run_suite(base_path, args.suite, args.agent, args.timeout, None, args.dry_run, args.base)
            candidate = run_suite(
                candidate_path,
                args.suite,
                args.agent,
                args.timeout,
                None,
                args.dry_run,
                args.candidate,
            )
            if args.dry_run:
                return 0
            return compare_results(base, candidate)
        finally:
            if args.keep_worktrees:
                print(f"Keeping worktrees under {tmp_path}")
            else:
                remove_worktree(REPO_ROOT, base_path)
                remove_worktree(REPO_ROOT, candidate_path)
                shutil.rmtree(tmp_path, ignore_errors=True)

    output = Path(args.output) if args.output else None
    result = run_suite(REPO_ROOT, args.suite, args.agent, args.timeout, output, args.dry_run, "current")
    if args.dry_run:
        return 0
    return 0 if result["passed"] == result["total"] else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        raise SystemExit(130)
