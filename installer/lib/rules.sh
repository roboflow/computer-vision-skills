#!/usr/bin/env bash
# rules.sh — install / remove a Roboflow managed block in a markdown rules file.
#
# Markers: <!-- BEGIN ROBOFLOW --> ... <!-- END ROBOFLOW -->
# Only content inside the markers is touched. Everything outside is preserved.
#
# Used for:
#   CLAUDE.md / AGENTS.md / GEMINI.md (project-root rules files)
#   .cursor/rules/roboflow.mdc (Cursor's per-rule file format — its own format,
#     so for Cursor we write a single-rule file rather than a managed block)

RF_RULES_BEGIN_MARKER="<!-- BEGIN ROBOFLOW -->"
RF_RULES_END_MARKER="<!-- END ROBOFLOW -->"

# rf::rules::template_path <flavor>
# Map flavor → template file. Flavor is the basename without extension:
#   claude  → templates/rules/CLAUDE.roboflow.md
#   agents  → templates/rules/AGENTS.roboflow.md
#   gemini  → templates/rules/GEMINI.roboflow.md
#   cursor  → templates/rules/cursor-roboflow.mdc
rf::rules::template_path() {
    local flavor="$1"
    case "$flavor" in
        claude) printf '%s/templates/rules/CLAUDE.roboflow.md' "$RF_REPO_DIR" ;;
        agents) printf '%s/templates/rules/AGENTS.roboflow.md' "$RF_REPO_DIR" ;;
        gemini) printf '%s/templates/rules/GEMINI.roboflow.md' "$RF_REPO_DIR" ;;
        cursor) printf '%s/templates/rules/cursor-roboflow.mdc' "$RF_REPO_DIR" ;;
        *) return 1 ;;
    esac
}

# rf::rules::install_managed_block <target_file> <flavor>
# Update the BEGIN/END block in <target_file> with the content of the
# template for <flavor>. If the markers don't exist, append the block. If
# they do, replace the slice between them. Preserves everything else.
rf::rules::install_managed_block() {
    local target="$1" flavor="$2"
    local tpl
    tpl="$(rf::rules::template_path "$flavor")" || return 1
    [[ -f "$tpl" ]] || { rf::warn "rules template not found: $tpl"; return 1; }

    if [[ "${RF_OPT_DRY_RUN:-0}" == "1" ]]; then
        rf::info "[dry-run] would update Roboflow managed block in $target"
        return 0
    fi

    rf::ensure_dir "$(dirname "$target")"

    local body
    body="$(cat "$tpl")"

    if [[ -f "$target" ]]; then
        rf::backup "$target" >/dev/null
        # If existing markers are present, replace the slice between them.
        if grep -F "$RF_RULES_BEGIN_MARKER" "$target" >/dev/null 2>&1; then
            BEGIN="$RF_RULES_BEGIN_MARKER" END="$RF_RULES_END_MARKER" BODY="$body" \
                python3 -c '
import os, re, sys
with open(sys.argv[1]) as fh:
    text = fh.read()
begin = re.escape(os.environ["BEGIN"])
end   = re.escape(os.environ["END"])
new_block = os.environ["BEGIN"] + "\n" + os.environ["BODY"].rstrip() + "\n" + os.environ["END"]
new_text = re.sub(begin + r".*?" + end, new_block, text, count=1, flags=re.DOTALL)
sys.stdout.write(new_text)
' "$target" | rf::atomic_write "$target"
        else
            # No markers; append a new managed block at EOF.
            { cat "$target"; printf '\n%s\n%s\n%s\n' "$RF_RULES_BEGIN_MARKER" "$body" "$RF_RULES_END_MARKER"; } | rf::atomic_write "$target"
        fi
    else
        # New file.
        printf '%s\n%s\n%s\n' "$RF_RULES_BEGIN_MARKER" "$body" "$RF_RULES_END_MARKER" | rf::atomic_write "$target"
    fi
    rf::ok "wrote Roboflow managed block to $target"
}

# rf::rules::install_cursor_mdc <target_file>
# Write a single-rule .mdc file. Cursor expects a per-rule file; we don't
# wrap in begin/end markers. Idempotent: replaces the file in full from the
# template.
rf::rules::install_cursor_mdc() {
    local target="$1"
    local tpl
    tpl="$(rf::rules::template_path cursor)" || return 1
    [[ -f "$tpl" ]] || { rf::warn "rules template not found: $tpl"; return 1; }

    if [[ "${RF_OPT_DRY_RUN:-0}" == "1" ]]; then
        rf::info "[dry-run] would write Cursor rule file at $target"
        return 0
    fi

    rf::ensure_dir "$(dirname "$target")"
    [[ -f "$target" ]] && rf::backup "$target" >/dev/null
    cp "$tpl" "$target"
    rf::ok "wrote Cursor rule file at $target"
}

# rf::rules::remove_managed_block <target_file>
# Strip the BEGIN/END block and surrounding blank-line padding. Leaves the
# rest of the file untouched. Removes the file if it ends up empty.
rf::rules::remove_managed_block() {
    local target="$1"
    [[ -f "$target" ]] || return 0

    if [[ "${RF_OPT_DRY_RUN:-0}" == "1" ]]; then
        rf::info "[dry-run] would strip Roboflow managed block from $target"
        return 0
    fi

    rf::backup "$target" >/dev/null

    BEGIN="$RF_RULES_BEGIN_MARKER" END="$RF_RULES_END_MARKER" python3 -c '
import os, re, sys
with open(sys.argv[1]) as fh:
    text = fh.read()
begin = re.escape(os.environ["BEGIN"])
end   = re.escape(os.environ["END"])
new_text = re.sub(r"\n*" + begin + r".*?" + end + r"\n*", "\n", text, count=1, flags=re.DOTALL)
new_text = new_text.strip("\n")
if new_text:
    new_text += "\n"
sys.stdout.write(new_text)
' "$target" | rf::atomic_write "$target"

    # If file is now empty (or whitespace-only), drop it.
    if [[ ! -s "$target" ]] || [[ -z "$(tr -d '[:space:]' <"$target")" ]]; then
        rm -f "$target"
        rf::ok "removed empty $target"
    else
        rf::ok "stripped Roboflow managed block from $target"
    fi
}

# rf::rules::remove_cursor_mdc <target_file>
# Roboflow owns the file in full; safe to remove if it matches the template
# OR if --force is passed.
rf::rules::remove_cursor_mdc() {
    local target="$1"
    [[ -f "$target" ]] || return 0
    if [[ "${RF_OPT_DRY_RUN:-0}" == "1" ]]; then
        rf::info "[dry-run] would remove $target"
        return 0
    fi
    rf::backup "$target" >/dev/null
    rm -f "$target"
    rf::ok "removed $target"
}
