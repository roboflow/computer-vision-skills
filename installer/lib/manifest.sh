#!/usr/bin/env bash
# manifest.sh — read/write the Roboflow installer manifest.
#
# Path: $ROBOFLOW_CONFIG_DIR/installations.json (matches the Python SDK).
# Schema:
#   {
#     "schema_version": 1,
#     "installer_version": "<semver>",
#     "installations": [
#       { "host_id", "component", "scope", ... }
#     ]
#   }
#
# Components: "plugin" (host plugin install), "mcp", "skill", "rules".

RF_INSTALLER_VERSION="0.1.0"

rf::manifest::path() {
    local dir
    dir="$(rf::auth::sdk_config_dir)"
    printf '%s/installations.json' "$dir"
}

rf::manifest::ensure() {
    local path
    path="$(rf::manifest::path)"
    if [[ ! -f "$path" ]]; then
        rf::ensure_dir "$(dirname "$path")"
        rf::atomic_write "$path" <<EOF
{
  "schema_version": 1,
  "installer_version": "$RF_INSTALLER_VERSION",
  "installations": []
}
EOF
        chmod 600 "$path" 2>/dev/null || true
    fi
}

# rf::manifest::record <entry-json>
# Append (or replace, by host_id+component+scope) an entry in installations[].
rf::manifest::record() {
    local entry="$1"
    rf::manifest::ensure
    rf::json::has_tool || return 1
    local path
    path="$(rf::manifest::path)"

    local updated
    if [[ "$(rf::json::tool)" == "python3" ]]; then
        updated="$(
            FILE="$path" ENTRY="$entry" python3 -c '
import json, os, sys
with open(os.environ["FILE"]) as fh:
    data = json.load(fh)
entry = json.loads(os.environ["ENTRY"])
key = (entry.get("host_id"), entry.get("component"), entry.get("scope", "global"), entry.get("skill_name"))
out = []
replaced = False
for item in data.get("installations", []):
    item_key = (item.get("host_id"), item.get("component"), item.get("scope", "global"), item.get("skill_name"))
    if item_key == key:
        out.append(entry)
        replaced = True
    else:
        out.append(item)
if not replaced:
    out.append(entry)
data["installations"] = out
data["installer_version"] = entry.get("installer_version", data.get("installer_version"))
json.dump(data, sys.stdout, indent=2)
sys.stdout.write("\n")
'
        )" || return 1
    else
        updated="$(
            jq --argjson entry "$entry" '
                .installations = (
                    [(.installations[]? | select(
                        .host_id != $entry.host_id
                        or .component != $entry.component
                        or (.scope // "global") != ($entry.scope // "global")
                        or (.skill_name // null) != ($entry.skill_name // null)
                    ))] + [$entry]
                )
            ' "$path"
        )" || return 1
    fi

    printf '%s' "$updated" | rf::atomic_write "$path"
}

# rf::manifest::remove <host_id> <component> [<scope>] [<skill_name>]
# Remove matching entries.
rf::manifest::remove() {
    local host="$1" component="$2" scope="${3:-global}" skill="${4:-}"
    local path
    path="$(rf::manifest::path)"
    [[ -f "$path" ]] || return 0
    rf::json::has_tool || return 1

    local updated
    if [[ "$(rf::json::tool)" == "python3" ]]; then
        updated="$(
            FILE="$path" HOST="$host" COMPONENT="$component" SCOPE="$scope" SKILL="$skill" python3 -c '
import json, os, sys
with open(os.environ["FILE"]) as fh:
    data = json.load(fh)
host = os.environ["HOST"]; component = os.environ["COMPONENT"]
scope = os.environ["SCOPE"]; skill = os.environ["SKILL"] or None
out = []
for item in data.get("installations", []):
    if item.get("host_id") == host and item.get("component") == component \
       and (item.get("scope") or "global") == scope \
       and (item.get("skill_name") or None) == skill:
        continue
    out.append(item)
data["installations"] = out
json.dump(data, sys.stdout, indent=2)
sys.stdout.write("\n")
'
        )" || return 1
    else
        updated="$(
            jq --arg host "$host" --arg component "$component" --arg scope "$scope" --arg skill "$skill" '
                .installations = [
                    .installations[]? | select(
                        .host_id != $host
                        or .component != $component
                        or (.scope // "global") != $scope
                        or (.skill_name // "") != $skill
                    )
                ]
            ' "$path"
        )" || return 1
    fi

    printf '%s' "$updated" | rf::atomic_write "$path"
}

# rf::manifest::list [<host_id>]
# Print the full installations array (or filtered to one host) as JSON to stdout.
rf::manifest::list() {
    local host="${1:-}"
    local path
    path="$(rf::manifest::path)"
    [[ -f "$path" ]] || { echo "[]"; return 0; }
    rf::json::has_tool || { cat "$path"; return 0; }

    if [[ "$(rf::json::tool)" == "python3" ]]; then
        FILE="$path" HOST="$host" python3 -c '
import json, os, sys
with open(os.environ["FILE"]) as fh:
    data = json.load(fh)
items = data.get("installations", [])
host = os.environ["HOST"]
if host:
    items = [it for it in items if it.get("host_id") == host]
json.dump(items, sys.stdout, indent=2)
sys.stdout.write("\n")
'
    else
        if [[ -n "$host" ]]; then
            jq --arg host "$host" '[.installations[]? | select(.host_id == $host)]' "$path"
        else
            jq '.installations // []' "$path"
        fi
    fi
}
