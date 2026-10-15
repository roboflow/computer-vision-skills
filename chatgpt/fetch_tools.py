"""Refresh chatgpt/tools.json from the tools the live MCP server lists on each surface."""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
from urllib.request import Request, urlopen

DEFAULT_SERVER = "https://mcp.roboflow.com"
OUTPUT = Path(__file__).resolve().parent / "tools.json"
PROTOCOL_VERSION = "2025-06-18"


def parse_response(body: str, request_id: int) -> dict:
    """Read the JSON-RPC reply to `request_id`, sent as plain JSON or as a server-sent event stream."""
    text = body.replace("\r\n", "\n").strip()
    if text.startswith("{"):
        return json.loads(text)
    for event in text.split("\n\n"):
        lines = [line[len("data:"):] for line in event.split("\n") if line.startswith("data:")]
        if not lines:
            continue
        message = json.loads("\n".join(line[1:] if line.startswith(" ") else line for line in lines))
        if isinstance(message, dict) and message.get("id") == request_id:
            return message
    raise ValueError("MCP server returned no JSON-RPC reply to the tools/list request")


def list_tool_names(endpoint: str, api_key: str) -> set[str]:
    names: set[str] = set()
    cursor = None
    while True:
        params = {"cursor": cursor} if cursor else {}
        request = Request(
            endpoint,
            data=json.dumps({"jsonrpc": "2.0", "id": 1, "method": "tools/list", "params": params}).encode(),
            headers={
                "Content-Type": "application/json",
                "Accept": "application/json, text/event-stream",
                "MCP-Protocol-Version": PROTOCOL_VERSION,
                "x-api-key": api_key,
            },
        )
        with urlopen(request, timeout=60) as response:
            message = parse_response(response.read().decode("utf-8"), 1)
        if "error" in message:
            raise RuntimeError(f"{endpoint} tools/list failed: {message['error']}")
        result = message.get("result")
        if not isinstance(result, dict) or not isinstance(result.get("tools"), list):
            raise ValueError(f"{endpoint} returned a malformed tools/list result")
        for tool in result["tools"]:
            if not isinstance(tool, dict) or not isinstance(tool.get("name"), str) or not tool["name"]:
                raise ValueError(f"{endpoint} listed a tool without a name")
            names.add(tool["name"])
        cursor = result.get("nextCursor")
        if not cursor:
            return names


def fetch(server: str, api_key: str) -> dict:
    server = server.rstrip("/")
    if not server.startswith("https://"):
        raise ValueError("MCP server must use HTTPS")
    default = list_tool_names(f"{server}/mcp", api_key)
    openai = list_tool_names(f"{server}/openai/mcp", api_key)
    if not openai:
        raise ValueError("/openai/mcp listed no tools")
    if openai - default:
        raise ValueError(f"/openai/mcp lists tools /mcp does not: {sorted(openai - default)}")
    return {
        "server": server,
        "fetched_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "visible": sorted(openai),
        "hidden": sorted(default - openai),
    }


def refresh(server: str, api_key: str, output: Path = OUTPUT) -> dict:
    """Fetch both surfaces, then replace `output`. A failure leaves the old file untouched."""
    payload = fetch(server, api_key)
    output.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    return payload


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--server", default=DEFAULT_SERVER,
                        help="MCP origin, e.g. https://mcp.roboflow.one for staging")
    parser.add_argument("--output", type=Path, default=OUTPUT)
    args = parser.parse_args()
    api_key = os.environ.get("ROBOFLOW_API_KEY")
    if not api_key:
        raise SystemExit("Set ROBOFLOW_API_KEY to a Roboflow API key")
    payload = refresh(args.server, api_key, args.output)
    print(f"Wrote {len(payload['visible'])} visible and {len(payload['hidden'])} hidden tools to {args.output}")
