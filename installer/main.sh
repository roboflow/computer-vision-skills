#!/usr/bin/env bash
# main.sh — Roboflow agents.sh installer orchestration.
#
# Sourced lib + host adapters. Phase 1 supports plugin-based installs for
# Claude Code CLI and Codex CLI. Later phases add config-file hosts.

set -euo pipefail

# Locate ourselves so lib + hosts source correctly whether we're running from
# the local checkout (~/Code/computer-vision-skills/installer/main.sh) or the
# tarball-extracted cache (~/.cache/roboflow-agents/dl.XXXXXX/installer/main.sh).
RF_INSTALLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RF_REPO_DIR="$(cd "$RF_INSTALLER_DIR/.." && pwd)"
export RF_INSTALLER_DIR RF_REPO_DIR

# Default: tell host adapters which marketplace source to register.
export ROBOFLOW_AGENTS_REPO="${ROBOFLOW_AGENTS_REPO:-roboflow/computer-vision-skills}"

# shellcheck source=lib/common.sh
source "$RF_INSTALLER_DIR/lib/common.sh"
# shellcheck source=lib/json_io.sh
source "$RF_INSTALLER_DIR/lib/json_io.sh"
# shellcheck source=lib/detect.sh
source "$RF_INSTALLER_DIR/lib/detect.sh"
# shellcheck source=lib/auth.sh
source "$RF_INSTALLER_DIR/lib/auth.sh"
# shellcheck source=lib/manifest.sh
source "$RF_INSTALLER_DIR/lib/manifest.sh"
# shellcheck source=lib/mcp.sh
source "$RF_INSTALLER_DIR/lib/mcp.sh"
# shellcheck source=lib/skills.sh
source "$RF_INSTALLER_DIR/lib/skills.sh"
# shellcheck source=lib/rules.sh
source "$RF_INSTALLER_DIR/lib/rules.sh"

# --- usage ---------------------------------------------------------------

rf::usage() {
    cat <<'EOF'
agents.sh — install Roboflow into your coding agents

USAGE
  bash agents.sh [flags]

  curl -fsSL https://roboflow.com/agents.sh | bash
  curl -fsSL https://roboflow.com/agents.sh | bash -s -- [flags]

FLAGS
  --host=<id,...>       Restrict to specific agent IDs (repeatable / comma-sep)
  --all                 All detected agents (implied with --yes if no --host)
  --skills-only         Install skills only
  --mcp-only            Install MCP only
  --rules-only          Install rules / managed-blocks only
  --no-skills           Skip skills component
  --no-mcp              Skip MCP component
  --no-rules            Skip rules component
  --global              Default scope (per-user installs)
  --project             Project-scoped install (no inline secrets allowed)
  --api-key=<key>       Override API key resolution
  --workspace=<url>     Pick a workspace from the Python SDK config
  --inline-key          Write key literally (global scope only)
  --auth-skip           Skip auth wiring; install everything else
  --update              Reconcile-only mode (also implicit on re-run)
  --uninstall           Remove Roboflow-managed components
  --dry-run             Print plan; no writes
  --force               Override safety checks
  --force-skill=<name>  Overwrite a specific user-edited skill
  --yes, -y             No prompts; use defaults for unspecified decisions
  --version             Print installer version + repo SHA
  --help, -h            This help

KNOWN HOST IDS
  claude-code-cli       Claude Code CLI (via `claude plugin install`)
  codex-cli             Codex CLI (registers marketplace; finish via `/plugins`)
  cursor-desktop        Cursor (~/.cursor/mcp.json + skills)
  claude-desktop        Claude Desktop (claude_desktop_config.json)
  copilot-cli           GitHub Copilot CLI
  gemini-cli            Gemini CLI
  windsurf-desktop      Windsurf
  vscode-copilot        VS Code Copilot (servers + inputs schema)
  opencode-cli          OpenCode CLI (mcp + remote schema)

  See docs/INSTALLER.md for full reference and docs/per-agent/<host>.md
  for manual install instructions.

ENV
  ROBOFLOW_API_KEY      Read by adapters and the MCP server at runtime
  ROBOFLOW_CONFIG_DIR   Override Python SDK config dir (defaults to ~/.config/roboflow)
  ROBOFLOW_AGENTS_REF   Pin a branch or tag for the bootstrap tarball
  ROBOFLOW_AGENTS_REPO  Override the source repo (default roboflow/computer-vision-skills)

EXIT CODES
  0  ok
  1  install failure
  2  invalid usage
  3  no supported hosts found / selected
  4  unsafe operation blocked
EOF
}

# --- arg parsing ---------------------------------------------------------

RF_OPT_HOSTS=()
RF_OPT_ALL=0
RF_OPT_COMPONENTS=()           # any of: skills, mcp, rules (positive scope)
RF_OPT_NO_COMPONENTS=()        # any of: skills, mcp, rules
RF_OPT_SCOPE="global"
RF_OPT_API_KEY=""
RF_OPT_WORKSPACE=""
RF_OPT_INLINE_KEY=0
RF_OPT_AUTH_SKIP=0
RF_OPT_MODE="install"          # install | update | uninstall
RF_OPT_DRY_RUN=0
RF_OPT_FORCE=0
RF_OPT_FORCE_SKILLS=()
RF_YES=0

rf::parse_args() {
    while (($#)); do
        case "$1" in
            --host=*) IFS=',' read -r -a additions <<<"${1#*=}"
                      RF_OPT_HOSTS+=("${additions[@]}") ;;
            --all) RF_OPT_ALL=1 ;;
            --skills-only) RF_OPT_COMPONENTS=("skills") ;;
            --mcp-only) RF_OPT_COMPONENTS=("mcp") ;;
            --rules-only) RF_OPT_COMPONENTS=("rules") ;;
            --no-skills) RF_OPT_NO_COMPONENTS+=("skills") ;;
            --no-mcp)    RF_OPT_NO_COMPONENTS+=("mcp") ;;
            --no-rules)  RF_OPT_NO_COMPONENTS+=("rules") ;;
            --global)  RF_OPT_SCOPE="global" ;;
            --project) RF_OPT_SCOPE="project" ;;
            --api-key=*) RF_OPT_API_KEY="${1#*=}" ;;
            --workspace=*) RF_OPT_WORKSPACE="${1#*=}" ;;
            --inline-key) RF_OPT_INLINE_KEY=1 ;;
            --auth-skip) RF_OPT_AUTH_SKIP=1 ;;
            --update) RF_OPT_MODE="update" ;;
            --uninstall) RF_OPT_MODE="uninstall" ;;
            --dry-run) RF_OPT_DRY_RUN=1 ;;
            --force) RF_OPT_FORCE=1 ;;
            --force-skill=*) RF_OPT_FORCE_SKILLS+=("${1#*=}") ;;
            --yes|-y) RF_YES=1 ;;
            --version)
                printf 'agents.sh installer %s\n' "${RF_INSTALLER_VERSION:-dev}"
                printf 'repo: %s@%s\n' "$ROBOFLOW_AGENTS_REPO" "${ROBOFLOW_AGENTS_REF:-(local)}"
                exit 0
                ;;
            --help|-h) rf::usage; exit 0 ;;
            *)
                rf::err "unknown flag: $1"
                rf::info "Run with --help for usage."
                RF_EXIT_CODE=2 rf::die "invalid usage"
                ;;
        esac
        shift
    done

    # --project + --inline-key is allowed but loud — project files are
    # commit-able, so the user is opting in to a secret in a tracked file.
    # Host adapters can warn further at write time.
    if [[ "$RF_OPT_SCOPE" == "project" ]] && [[ "$RF_OPT_INLINE_KEY" == "1" ]]; then
        rf::warn "--inline-key + --project: literal API key will be written into project config — make sure that file isn't committed."
    fi

    export RF_OPT_API_KEY RF_OPT_WORKSPACE RF_OPT_AUTH_SKIP RF_OPT_INLINE_KEY \
           RF_OPT_SCOPE RF_OPT_DRY_RUN RF_OPT_FORCE RF_YES \
           RF_INSTALLER_VERSION
}

# --- host selection ------------------------------------------------------

# Print one host id per line that we should operate on.
rf::select_hosts() {
    local detected
    detected="$(rf::detect::all)"

    if [[ ${#RF_OPT_HOSTS[@]} -gt 0 ]]; then
        # Validate up front so we can return non-zero (rather than `exit` from
        # within a process substitution, which only exits the subshell).
        local id
        for id in "${RF_OPT_HOSTS[@]}"; do
            # `-Fx` without `-q` so grep reads the whole input — `-q` early
            # exit + `pipefail` would mark the pipeline failed via SIGPIPE.
            if ! rf::detect::known_ids | grep -Fx -- "$id" >/dev/null 2>&1; then
                rf::err "unknown host id: $id"
                rf::info "Known IDs: $(rf::detect::known_ids | paste -sd, -)"
                return 2
            fi
        done
        for id in "${RF_OPT_HOSTS[@]}"; do
            printf '%s\n' "$id"
        done
        return 0
    fi

    if [[ -z "$detected" ]]; then
        return 0
    fi

    if [[ "$RF_OPT_ALL" == "1" ]] || [[ "$RF_YES" == "1" ]]; then
        printf '%s\n' "$detected" | awk -F'|' '{print $1}'
        return 0
    fi

    rf::header "Detected agents"
    local -a ids=() labels=() hints=()
    local _kind
    while IFS='|' read -r id _kind label hint; do
        ids+=("$id"); labels+=("$label"); hints+=("$hint")
        rf::info "  $((${#ids[@]})). $label  ${RF_COLOR_DIM}— $hint${RF_COLOR_RESET}"
    done <<<"$detected"

    rf::info ""
    local choice
    choice="$(rf::prompt "Configure which? Comma-separated numbers, or \"all\":" "all")"
    if [[ "$choice" == "all" ]] || [[ -z "$choice" ]]; then
        printf '%s\n' "${ids[@]}"
        return 0
    fi
    local picks=()
    IFS=',' read -r -a parts <<<"$choice"
    local p
    for p in "${parts[@]}"; do
        p="$(printf '%s' "$p" | tr -d '[:space:]')"
        if [[ "$p" =~ ^[0-9]+$ ]] && [[ "$p" -ge 1 ]] && [[ "$p" -le "${#ids[@]}" ]]; then
            picks+=("${ids[$((p - 1))]}")
        fi
    done
    printf '%s\n' "${picks[@]}"
}

# --- per-host dispatch ---------------------------------------------------

rf::run_host() {
    local id="$1"
    local script="$RF_INSTALLER_DIR/hosts/${id//-/_}.sh"
    if [[ ! -f "$script" ]]; then
        rf::warn "no adapter for $id (not yet implemented in this installer version)"
        return 0
    fi
    # shellcheck source=/dev/null
    source "$script"

    local fn_base="rf::host::${id//-/_}"
    case "$RF_OPT_MODE" in
        install) "${fn_base}::install" ;;
        update)  "${fn_base}::install" ;;     # idempotent re-run for plugin hosts
        uninstall)
            if declare -F "${fn_base}::uninstall" >/dev/null; then
                "${fn_base}::uninstall"
            else
                rf::warn "$id has no uninstall hook; skipping"
            fi
            ;;
        *) RF_EXIT_CODE=2 rf::die "unknown mode: $RF_OPT_MODE" ;;
    esac
}

# --- entry ---------------------------------------------------------------

rf::main() {
    rf::parse_args "$@"

    # Compute per-component flags. Default is "all components on" — adapters
    # that don't apply for a given component just no-op.
    RF_DO_MCP=1; RF_DO_SKILLS=1; RF_DO_RULES=1
    if [[ ${#RF_OPT_COMPONENTS[@]} -gt 0 ]]; then
        # --skills-only / --mcp-only / --rules-only narrow to just one.
        RF_DO_MCP=0; RF_DO_SKILLS=0; RF_DO_RULES=0
        local c
        for c in "${RF_OPT_COMPONENTS[@]}"; do
            case "$c" in
                skills) RF_DO_SKILLS=1 ;;
                mcp) RF_DO_MCP=1 ;;
                rules) RF_DO_RULES=1 ;;
            esac
        done
    fi
    if [[ ${#RF_OPT_NO_COMPONENTS[@]} -gt 0 ]]; then
        local c
        for c in "${RF_OPT_NO_COMPONENTS[@]}"; do
            case "$c" in
                skills) RF_DO_SKILLS=0 ;;
                mcp) RF_DO_MCP=0 ;;
                rules) RF_DO_RULES=0 ;;
            esac
        done
    fi
    export RF_DO_MCP RF_DO_SKILLS RF_DO_RULES

    rf::header "Roboflow agents installer"
    rf::dim "  source repo: $ROBOFLOW_AGENTS_REPO"
    rf::dim "  scope:       $RF_OPT_SCOPE"
    rf::dim "  mode:        $RF_OPT_MODE"
    [[ "$RF_OPT_DRY_RUN" == "1" ]] && rf::dim "  dry-run:     yes"

    # Capture select_hosts output via a temp file so we can also propagate
    # its exit status (process substitution discards it).
    local select_tmp select_rc
    select_tmp="$(mktemp)"
    rf::select_hosts >"$select_tmp"
    select_rc=$?
    if [[ $select_rc -ne 0 ]]; then
        rm -f "$select_tmp"
        exit "$select_rc"
    fi
    local -a selected=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && selected+=("$line")
    done <"$select_tmp"
    rm -f "$select_tmp"

    if [[ ${#selected[@]} -eq 0 ]]; then
        rf::warn "no supported coding agents detected (or selected)"
        rf::info "Install one and re-run, or pass --host=<id> to override detection."
        rf::info "Known host IDs: $(rf::detect::known_ids | paste -sd, -)"
        exit 3
    fi

    if [[ "$RF_OPT_MODE" == "uninstall" ]] && [[ "$RF_YES" != "1" ]] && ! rf::confirm "Remove Roboflow from: ${selected[*]} ?"; then
        rf::info "aborted."
        exit 0
    fi

    if [[ "$RF_OPT_AUTH_SKIP" != "1" ]] && [[ "$RF_OPT_MODE" != "uninstall" ]]; then
        rf::auth::resolve
        if [[ -n "${RF_API_KEY:-}" ]]; then
            rf::dim "  api key:     resolved from ${RF_API_KEY_SOURCE:-?}"
        fi
    fi

    local -a results=()
    local rc
    for host in "${selected[@]}"; do
        if rf::run_host "$host"; then
            results+=("$host:ok")
        else
            rc=$?
            results+=("$host:fail($rc)")
        fi
    done

    rf::header "Summary"
    local r
    for r in "${results[@]}"; do
        if [[ "$r" == *:ok ]]; then
            rf::ok "${r%:*}"
        else
            rf::err "$r"
        fi
    done

    if [[ "$RF_OPT_MODE" != "uninstall" ]] && [[ -n "${RF_API_KEY:-}" ]] && [[ "${ROBOFLOW_API_KEY:-}" != "$RF_API_KEY" ]]; then
        rf::auth::shell_export_hint
    fi

    local failed=0
    for r in "${results[@]}"; do
        [[ "$r" == *:fail* ]] && failed=1
    done
    [[ $failed -eq 1 ]] && exit 1
    exit 0
}

rf::main "$@"
