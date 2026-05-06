# Local Tooling — When MCP Isn't Enough

> **Tip:** Prefer the [Roboflow MCP server](https://github.com/roboflow/roboflow-mcp) for anything it covers — it handles auth and needs nothing installed locally. This page is for the gaps where you need local Python tooling.

## When you need local tooling

Reach for local Python packages only when an operation has no MCP equivalent.

| Need                                                                                                             | Install | Surface |
|------------------------------------------------------------------------------------------------------------------|---|---|
| Inference inside your **own application** (server, script, notebook)                                             | `inference-sdk` | `InferenceHTTPClient` |
| **Batch Processing** / **Data Staging** (see [`batch-staging`](batch-staging.md), [`batch-jobs`](batch-jobs.md)) | `inference-cli` | `inference rf-cloud …` |
| **Self-hosted inference server** (Docker, on-prem, edge)                                                         | `inference-cli` | `inference server start` |
| Asset scripts that need typed Python objects (e.g. [`bin/poll_batch_job.py`](bin/poll_batch_job.py))             | `inference-cli` | `from inference_cli.lib.roboflow_cloud…` |

## Confirm the target env with the user first

**Before installing anything, ask which Python env to install into — the user owns that decision.** Don't assume `uv`, conda, or venv based on what looks cleanest; an agent that silently picks an env can pollute the system Python, break a pre-existing project env, or duplicate dependencies the user already has.

Ask (or infer from explicit prior signals like `CLAUDE.md`/memory) and always(!) confirm:

- Is there an existing project env to reuse? (look for `.venv/`, `pyproject.toml` + `uv.lock`, an active conda env, an `environment.yml`)
- If creating a new env, which manager — `uv`, conda, or stdlib `venv`?
- Which Python version, if not already pinned?

Only after the user has confirmed should you run `pip install` / `uv pip install` / `conda install`. The recommendations below are defaults to *propose*, not defaults to *act on*.

## Recommended setup: `uv`

[uv](https://docs.astral.sh/uv/) is the recommended Python package + env manager for these tools. Fast, reproducible, no boilerplate. Default to `uv` unless the user explicitly asks for something else.

```bash
# Install uv (one-time; see docs.astral.sh/uv for alternative installers)
curl -LsSf https://astral.sh/uv/install.sh | sh

# Create a project env with the right Python version
uv venv --python 3.12

# Install only what you need
uv pip install inference-sdk         # integration scripts
uv pip install inference-cli         # batch processing / data staging / self-hosted server
# (or both)

# Run anything via uv (auto-uses the project .venv)
uv run python script.py
uv run inference rf-cloud data-staging list-batches
```

For anything beyond a one-off, declare deps in `pyproject.toml`:

```toml
[project]
name = "my-roboflow-integration"
requires-python = ">=3.10"
dependencies = [
    "inference-sdk>=1.2",
    # "inference-cli>=1.2",   # add if you also need rf-cloud / self-hosted server
]
```

Then `uv sync` reproduces the env on any machine; `uv.lock` pins exact versions.

### Why `uv`

- Fast (seconds, not minutes) — single Rust-based resolver/installer.
- Deterministic resolution and lock file (`uv.lock`).
- Manages Python versions per project — no system-Python coupling.
- One command (`uv run`) handles both Python and console scripts.
- Same UX on Linux, macOS, Windows.

## Escape hatch: conda / venv

Use these only when `uv` is genuinely off-limits (existing pipeline, org policy, user explicitly insists). They work — they're just slower and more error-prone.

```bash
# conda
conda create -n my-roboflow python=3.12 -y
conda activate my-roboflow
pip install inference-sdk inference-cli

# stdlib venv
python3.12 -m venv .venv
source .venv/bin/activate
pip install inference-sdk inference-cli
```

In all cases: **never install into the system Python or a pre-existing shared env**. Both packages have heavy dependency trees that conflict easily with unrelated projects.

## Self-hosted server: Docker prerequisite

`inference server start` / `stop` / `status` are thin wrappers around Docker — they pull and run the `roboflow/roboflow-inference-server-*` image. **Before invoking any of them, verify Docker is installed and the daemon is running.** Don't just `pip install inference-cli` and assume the server will come up.

Quick check:

```bash
docker info --format '{{.ServerVersion}}'   # exits 0 only if the daemon is reachable
```

Note: `inference server start` itself will detect the running container, agent should just check if Docker daemon is running.

If it fails:

- **Not installed** — point the user to Docker Desktop (macOS/Windows) or the appropriate `docker-ce` package (Linux). Don't install Docker silently; it's a system-level dependency the user owns.
- **Installed but daemon not running** — on macOS/Windows, ask the user to launch Docker Desktop; on Linux, `sudo systemctl start docker` (or rootless equivalent - but ALWAYS ASK FOR CONFIRMATION OF SUCH OPERATION). Wait for the daemon before retrying.
- **Permission denied on the socket** (Linux) — user is not in the `docker` group; surface the error rather than `sudo`-ing around it.

## Common pitfalls

- **API key not picked up** — both packages read `ROBOFLOW_API_KEY` from the *environment of the process running them*. Export it in that shell, or use an `.env` loader explicitly. Never hardcode it in source; keep `.env` in `.gitignore`.
- **Same code, different deployment** — `api_url` is the only thing that changes between Serverless (`https://serverless.roboflow.com`), Dedicated (`https://<name>.roboflow.cloud`), and Self-hosted (`http://localhost:9001`).
