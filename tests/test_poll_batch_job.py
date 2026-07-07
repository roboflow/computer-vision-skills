"""Unit tests for skills/inference/bin/poll_batch_job.py.

The script imports ``inference_cli.lib`` internals at module load time. Those are
stubbed into ``sys.modules`` before import so the tests need neither the CLI
installed nor any network access.
"""

import importlib.util
import sys
import types
from pathlib import Path

import pytest


def _install_stub_inference_cli() -> None:
    """Register fake ``inference_cli`` modules so the script imports cleanly."""

    def ensure_pkg(name: str) -> types.ModuleType:
        if name not in sys.modules:
            mod = types.ModuleType(name)
            mod.__path__ = []  # mark as a package
            sys.modules[name] = mod
        return sys.modules[name]

    ensure_pkg("inference_cli")
    ensure_pkg("inference_cli.lib")
    ensure_pkg("inference_cli.lib.roboflow_cloud")
    ensure_pkg("inference_cli.lib.roboflow_cloud.batch_processing")
    api_ops = ensure_pkg(
        "inference_cli.lib.roboflow_cloud.batch_processing.api_operations"
    )
    api_ops.get_batch_job_metadata = lambda **kwargs: None  # overridden per-test
    common = ensure_pkg("inference_cli.lib.roboflow_cloud.common")
    common.get_workspace = lambda **kwargs: "ws"  # overridden per-test


_install_stub_inference_cli()

_MODULE_PATH = (
    Path(__file__).resolve().parents[1]
    / "skills"
    / "inference"
    / "bin"
    / "poll_batch_job.py"
)
_spec = importlib.util.spec_from_file_location("poll_batch_job", _MODULE_PATH)
poll = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(poll)


class FakeMeta:
    """Stand-in for the CLI's job-metadata object."""

    def __init__(
        self, current_stage="running", is_terminal=False, error=None, notification=None
    ):
        self.current_stage = current_stage
        self.is_terminal = is_terminal
        self.error = error
        self.last_notification = notification


# --- pure helpers ---------------------------------------------------------


@pytest.mark.parametrize(
    "value, expected",
    [
        ({"message": "hi", "type": "info"}, "hi"),
        ({"type": "info"}, "info"),
        ({"message": "", "type": ""}, ""),
        (None, ""),
        ("plain", "plain"),
        (123, "123"),
    ],
)
def test_summarize_notification(value, expected):
    assert poll._summarize_notification(value) == expected


@pytest.mark.parametrize(
    "value, expected",
    [
        ({"resultsBatches": ["b1", "b2"]}, ["b1", "b2"]),
        ({"resultsBatches": None}, []),
        ({"other": 1}, []),
        ("not-a-dict", []),
        (None, []),
    ],
)
def test_output_batches(value, expected):
    assert poll._output_batches(value) == expected


# --- argument parsing -----------------------------------------------------


@pytest.mark.parametrize("bad", ["0", "-5"])
def test_parse_args_rejects_nonpositive_interval(bad):
    with pytest.raises(SystemExit):
        poll._parse_args(["job", "--interval", bad])


def test_parse_args_rejects_nonpositive_max_wait():
    with pytest.raises(SystemExit):
        poll._parse_args(["job", "--max-wait", "0"])


def test_parse_args_clamps_small_interval():
    args = poll._parse_args(["job", "--interval", "1"])
    assert args.interval == poll.MIN_INTERVAL


def test_parse_args_keeps_valid_interval():
    args = poll._parse_args(["job", "--interval", "30"])
    assert args.interval == 30


# --- main() exit codes ----------------------------------------------------


def test_main_missing_api_key(monkeypatch):
    monkeypatch.delenv("ROBOFLOW_API_KEY", raising=False)
    assert poll.main(["job"]) == 2


def test_main_terminal_success(monkeypatch):
    monkeypatch.setenv("ROBOFLOW_API_KEY", "k")
    monkeypatch.setattr(poll, "get_workspace", lambda **kw: "ws")
    monkeypatch.setattr(
        poll,
        "get_batch_job_metadata",
        lambda **kw: FakeMeta(
            is_terminal=True, notification={"resultsBatches": ["b1"]}
        ),
    )
    assert poll.main(["job"]) == 0


def test_main_terminal_error(monkeypatch):
    monkeypatch.setenv("ROBOFLOW_API_KEY", "k")
    monkeypatch.setattr(poll, "get_workspace", lambda **kw: "ws")
    monkeypatch.setattr(
        poll,
        "get_batch_job_metadata",
        lambda **kw: FakeMeta(is_terminal=True, error="boom"),
    )
    assert poll.main(["job"]) == 1


def test_main_workspace_error_returns_3(monkeypatch):
    monkeypatch.setenv("ROBOFLOW_API_KEY", "k")

    def boom(**kw):
        raise RuntimeError("no network")

    monkeypatch.setattr(poll, "get_workspace", boom)
    assert poll.main(["job"]) == 3


def test_main_repeated_poll_errors_return_3(monkeypatch):
    monkeypatch.setenv("ROBOFLOW_API_KEY", "k")
    monkeypatch.setattr(poll, "get_workspace", lambda **kw: "ws")

    def boom(**kw):
        raise RuntimeError("transient")

    monkeypatch.setattr(poll, "get_batch_job_metadata", boom)
    monkeypatch.setattr(poll.time, "sleep", lambda s: None)
    assert poll.main(["job", "--max-wait", "100000"]) == 3


def test_main_timeout_returns_2(monkeypatch):
    monkeypatch.setenv("ROBOFLOW_API_KEY", "k")
    monkeypatch.setattr(poll, "get_workspace", lambda **kw: "ws")
    monkeypatch.setattr(
        poll, "get_batch_job_metadata", lambda **kw: FakeMeta(is_terminal=False)
    )
    monkeypatch.setattr(poll.time, "sleep", lambda s: None)
    # First call sets `start`; the second (in the elapsed check) blows past max-wait.
    clock = iter([0.0, 10_000.0, 10_000.0])
    monkeypatch.setattr(poll.time, "monotonic", lambda: next(clock))
    assert poll.main(["job", "--max-wait", "1"]) == 2
