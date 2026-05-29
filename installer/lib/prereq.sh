#!/usr/bin/env bash
# prereq.sh — runtime prerequisite checks and (optional) auto-install.
#
# Currently scoped to Node.js (npx) because that's the only third-party
# binary the installer needs end-users to have at runtime:
#   - Claude Code plugin's .mcp.json runs `npx -y mcp-remote@<ver> ...`
#     to bridge HTTP MCP over stdio (Claude Desktop's plugin runner
#     suppresses type:http MCPs).
#   - claude-desktop adapter writes the same bridge into
#     claude_desktop_config.json.

# Hosts whose install or runtime path needs `npx` on PATH.
RF_PREREQ_NODE_HOSTS="claude-code-cli codex-cli claude-desktop"

# Hosts whose install path shells out to git (`plugin marketplace add`
# clones the marketplace repo). On Windows this is auto-installable via
# winget (handled in prereq.ps1); on macOS/Linux git is effectively always
# present, so this side only checks and emits an actionable hint.
RF_PREREQ_GIT_HOSTS="claude-code-cli codex-cli"

rf::prereq::host_needs_node() {
    local id="$1" h
    for h in $RF_PREREQ_NODE_HOSTS; do
        [[ "$h" == "$id" ]] && return 0
    done
    return 1
}

# rf::prereq::any_needs_node <id> [<id>...]
# 0 if any of the given host IDs requires Node.
rf::prereq::any_needs_node() {
    local id
    for id in "$@"; do
        if rf::prereq::host_needs_node "$id"; then
            return 0
        fi
    done
    return 1
}

rf::prereq::host_needs_git() {
    local id="$1" h
    for h in $RF_PREREQ_GIT_HOSTS; do
        [[ "$h" == "$id" ]] && return 0
    done
    return 1
}

# rf::prereq::any_needs_git <id> [<id>...]
rf::prereq::any_needs_git() {
    local id
    for id in "$@"; do
        if rf::prereq::host_needs_git "$id"; then
            return 0
        fi
    done
    return 1
}

# Short label describing which path we'd use to install Node — surfaced in
# prompts and dry-run output so users know what's about to happen.
rf::prereq::node_method_label() {
    if rf::is_macos && rf::on_path brew; then
        printf 'Homebrew (brew install node)'
    else
        printf 'nvm (~/.nvm, no sudo)'
    fi
}

# rf::prereq::ensure_npx — verify npx is on PATH, or offer to install Node LTS.
# Returns 0 if npx is available (now or after install), non-zero otherwise.
# Respects $RF_OPT_NO_INSTALL_NODE (skip install, fail with a manual-install
# link) and $RF_YES (skip the consent prompt).
rf::prereq::ensure_npx() {
    if rf::on_path npx; then
        rf::dim "  npx detected: $(npx --version 2>/dev/null || echo '(unknown version)')"
        return 0
    fi

    rf::warn "npx (Node.js) is required for the selected hosts."
    rf::info "Roboflow MCP runs as \`npx -y mcp-remote …\` (an HTTP-to-stdio bridge)"
    rf::info "when your agent starts up. Manual install: https://nodejs.org"

    if [[ "${RF_OPT_NO_INSTALL_NODE:-0}" == "1" ]]; then
        rf::err "--no-install-node set; install Node.js manually and re-run."
        return 1
    fi

    if [[ "${RF_OPT_DRY_RUN:-0}" == "1" ]]; then
        rf::info "[dry-run] would install Node.js LTS via $(rf::prereq::node_method_label)"
        return 0
    fi

    if [[ "${RF_YES:-0}" != "1" ]]; then
        # Default to yes -- see the PowerShell equivalent for rationale:
        # refusing means the installer aborts and the user has to install
        # Node manually and re-run, which is worse than just letting us
        # install it. Saying no is still one keystroke (`n`).
        if ! rf::confirm "Install Node.js LTS now via $(rf::prereq::node_method_label)?" y; then
            rf::err "Node.js is required to proceed. Install it from https://nodejs.org and re-run agents.sh."
            return 1
        fi
    fi

    if ! rf::prereq::install_node_unix; then
        rf::err "Node.js install failed. Install manually from https://nodejs.org and re-run."
        return 1
    fi

    if rf::on_path npx; then
        rf::ok "Node.js installed: npx $(npx --version 2>/dev/null)"
        return 0
    fi
    rf::err "Node.js installer reported success but npx still not on PATH. Restart your shell and re-run."
    return 1
}

# rf::prereq::install_node_unix
# Install Node.js without sudo. Prefers Homebrew on macOS if present;
# falls back to nvm everywhere else (works on macOS and Linux without
# root, installs to ~/.nvm/).
rf::prereq::install_node_unix() {
    if rf::is_macos && rf::on_path brew; then
        rf::step "brew install node"
        brew install node || return 1
        return 0
    fi

    local nvm_ver="v0.40.1"
    rf::step "Installing nvm $nvm_ver + Node.js LTS"
    if ! curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${nvm_ver}/install.sh" | bash; then
        return 1
    fi
    # nvm's installer writes to ~/.bashrc / ~/.zshrc for future shells but
    # those don't apply to the current process — load nvm explicitly so
    # the rest of this installer run can find `npx`.
    export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
    # shellcheck disable=SC1091
    [[ -s "$NVM_DIR/nvm.sh" ]] && \. "$NVM_DIR/nvm.sh"
    nvm install --lts || return 1
    nvm use --lts || return 1
    return 0
}

# rf::prereq::ensure_git — verify git is present for hosts that clone the
# plugin marketplace. Returns 0 if git is available, non-zero otherwise.
#
# Unlike the Node path, this side does NOT auto-install: macOS/Linux have no
# universal no-sudo git installer (winget covers this on Windows, in
# prereq.ps1), and git is effectively always present on dev machines. So the
# common case returns 0 immediately; the rare missing-git case emits a
# platform-appropriate hint and fails clearly. Respects
# $RF_OPT_NO_INSTALL_GIT (suppresses the brew offer on macOS) and $RF_YES.
rf::prereq::ensure_git() {
    if rf::on_path git; then
        rf::dim "  git detected: $(git --version 2>/dev/null || echo '(unknown version)')"
        return 0
    fi

    rf::warn "git is required for Claude Code / Codex plugin operations."
    rf::info "\`plugin marketplace add\` clones the marketplace repo with git."

    # macOS with Homebrew is the one Unix case where a no-sudo install is
    # clean; offer it. Everywhere else, hint and fail.
    if rf::is_macos; then
        if [[ "${RF_OPT_NO_INSTALL_GIT:-0}" == "1" ]]; then
            rf::err "--no-install-git set; install git (e.g. \`xcode-select --install\`) and re-run."
            return 1
        fi
        if [[ "${RF_OPT_DRY_RUN:-0}" == "1" ]]; then
            if rf::on_path brew; then
                rf::info "[dry-run] would install git via Homebrew (brew install git)"
            else
                rf::info "[dry-run] would prompt to run: xcode-select --install"
            fi
            return 0
        fi
        if rf::on_path brew; then
            if [[ "${RF_YES:-0}" == "1" ]] || rf::confirm "Install git now via Homebrew (brew install git)?" y; then
                rf::step "brew install git"
                if brew install git && rf::on_path git; then
                    rf::ok "git installed: $(git --version 2>/dev/null)"
                    return 0
                fi
            fi
        else
            rf::info "Install the Xcode command line tools: xcode-select --install"
        fi
        rf::err "git is required to configure Claude Code / Codex. Install it and re-run."
        return 1
    fi

    # Linux / other: print the common package-manager invocations.
    rf::err "git not found. Install it and re-run, e.g.:"
    rf::info "  Debian/Ubuntu:  sudo apt-get install -y git"
    rf::info "  Fedora/RHEL:    sudo dnf install -y git"
    rf::info "  Alpine:         sudo apk add git"
    return 1
}
