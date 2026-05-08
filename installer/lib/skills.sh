#!/usr/bin/env bash
# skills.sh — install Roboflow skill directories into agent skill paths.
#
# Source: $RF_REPO_DIR/skills/<skill_name>/  (always available — either we're
# running from a local checkout, or the bootstrap downloaded the tarball).
#
# Per-skill sidecar: <dest>/.roboflow-install-manifest.json carrying:
#   - skill_name, host_id, scope
#   - installed_at, updated_at
#   - upstream_sha (if available; falls back to "local" when running from a
#     dev checkout)
#   - content_hash: sha256 over sorted file list + concatenated contents
#
# Update logic:
#   - pristine (current_hash == manifest.content_hash) → overwrite from upstream
#   - edited (mismatch)                                → skip + warn unless --force-skill=<name>
#   - upstream-only (skill exists upstream, not on disk) → install
#   - on-disk-only with Roboflow manifest, no upstream  → remove (with backup)
#   - on-disk-only without Roboflow manifest            → leave alone

rf::skills::source_dir() {
    printf '%s/skills' "$RF_REPO_DIR"
}

# Check if the source dir is present (it should always be, both in local
# checkout and tarball-extracted modes).
rf::skills::source_available() {
    [[ -d "$(rf::skills::source_dir)" ]]
}

rf::skills::list_upstream() {
    local src
    src="$(rf::skills::source_dir)"
    [[ -d "$src" ]] || return 0
    local d
    for d in "$src"/*/; do
        [[ -d "$d" ]] || continue
        [[ -f "${d}SKILL.md" ]] || continue
        basename "$d"
    done
}

# rf::skills::content_hash <dir>
# Compute sha256 over (sorted-relative-path + sha256-of-file) per regular file
# under <dir>, excluding the .roboflow-install-manifest.json sidecar.
rf::skills::content_hash() {
    local dir="$1"
    [[ -d "$dir" ]] || { printf 'missing'; return 0; }

    local hash_cmd=""
    if command -v sha256sum >/dev/null 2>&1; then
        hash_cmd="sha256sum"
    elif command -v shasum >/dev/null 2>&1; then
        hash_cmd="shasum -a 256"
    else
        rf::warn "no sha256 tool found; skipping content hash check"
        printf 'no-hash-tool'
        return 0
    fi

    (
        cd "$dir" || exit 1
        find . -type f \
            -not -name '.roboflow-install-manifest.json' \
            -not -name '.DS_Store' \
            | LC_ALL=C sort \
            | while IFS= read -r f; do
                # shellcheck disable=SC2086
                printf '%s ' "$f"
                $hash_cmd "$f" | awk '{print $1}'
            done \
            | $hash_cmd \
            | awk '{print $1}'
    )
}

rf::skills::manifest_path() {
    printf '%s/.roboflow-install-manifest.json' "$1"
}

rf::skills::write_sidecar() {
    local dest="$1" skill="$2" host_id="$3" scope="$4" upstream_sha="$5" content_hash="$6"
    local now
    now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    rf::atomic_write "$(rf::skills::manifest_path "$dest")" <<EOF
{
  "schema_version": 1,
  "skill_name": "$skill",
  "host_id": "$host_id",
  "scope": "$scope",
  "upstream_sha": "$upstream_sha",
  "content_hash": "sha256:$content_hash",
  "installer_version": "$RF_INSTALLER_VERSION",
  "installed_at": "$now",
  "updated_at": "$now"
}
EOF
}

# rf::skills::is_force_skill <name> — 0 if --force-skill=<name> was passed.
rf::skills::is_force_skill() {
    local name="$1"
    if [[ ${#RF_OPT_FORCE_SKILLS[@]} -eq 0 ]]; then
        return 1
    fi
    local f
    for f in "${RF_OPT_FORCE_SKILLS[@]}"; do
        [[ "$f" == "$name" ]] && return 0
    done
    return 1
}

# rf::skills::detect_upstream_sha
# Try `git rev-parse HEAD` against $RF_REPO_DIR; "local" if not a checkout.
rf::skills::detect_upstream_sha() {
    if command -v git >/dev/null 2>&1 && [[ -d "$RF_REPO_DIR/.git" ]]; then
        (cd "$RF_REPO_DIR" && git rev-parse HEAD 2>/dev/null) && return 0
    fi
    printf 'local'
}

# rf::skills::install_one <skill_name> <skills_dest_dir> <host_id> <scope>
# Install one skill into <skills_dest_dir>/<skill_name>/. Records sidecar +
# central manifest entry.
rf::skills::install_one() {
    local skill="$1" base="$2" host_id="$3" scope="$4"
    local src dest sidecar
    src="$(rf::skills::source_dir)/$skill"
    dest="$base/$skill"
    sidecar="$(rf::skills::manifest_path "$dest")"

    [[ -d "$src" ]] || { rf::warn "skill $skill not found in source ($src)"; return 1; }

    if [[ "${RF_OPT_DRY_RUN:-0}" == "1" ]]; then
        rf::info "[dry-run] would install skill $skill → $dest"
        return 0
    fi

    if [[ -d "$dest" ]] && [[ -f "$sidecar" ]]; then
        local current_hash manifest_hash
        current_hash="$(rf::skills::content_hash "$dest")"
        manifest_hash="$(rf::json::read_field "$sidecar" .content_hash 2>/dev/null | sed 's/^sha256://' || true)"
        if [[ -n "$manifest_hash" ]] && [[ "$current_hash" != "$manifest_hash" ]] \
           && ! rf::skills::is_force_skill "$skill"; then
            rf::warn "skill $skill has local edits; keeping them (run with --force-skill=$skill to overwrite)"
            return 0
        fi
    elif [[ -d "$dest" ]] && [[ ! -f "$sidecar" ]]; then
        # User-installed skill we didn't manage; refuse to clobber.
        if ! rf::skills::is_force_skill "$skill"; then
            rf::warn "$dest exists but has no Roboflow sidecar; not touching it (use --force-skill=$skill to overwrite)"
            return 0
        fi
    fi

    rf::ensure_dir "$base"
    [[ -d "$dest" ]] && rm -rf "$dest"
    cp -R "$src" "$dest"
    # Drop any stray macOS metadata.
    find "$dest" -name '.DS_Store' -delete 2>/dev/null || true

    local upstream_sha content_hash
    upstream_sha="$(rf::skills::detect_upstream_sha)"
    content_hash="$(rf::skills::content_hash "$dest")"
    rf::skills::write_sidecar "$dest" "$skill" "$host_id" "$scope" "$upstream_sha" "$content_hash"

    rf::manifest::record "$(cat <<EOF
{
  "host_id": "$host_id",
  "component": "skill",
  "scope": "$scope",
  "skill_name": "$skill",
  "skill_path": "$dest",
  "upstream_sha": "$upstream_sha",
  "content_hash": "sha256:$content_hash",
  "installer_version": "$RF_INSTALLER_VERSION",
  "installed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
)" || true

    rf::ok "installed skill $skill → $dest"
}

# rf::skills::install_all <skills_dest_dir> <host_id> <scope>
# Install every upstream skill, plus reconcile (remove no-longer-upstream
# Roboflow-managed skills under the same dir).
rf::skills::install_all() {
    local base="$1" host_id="$2" scope="$3"
    rf::skills::source_available || rf::die "skills source dir missing: $(rf::skills::source_dir)"

    local skill
    while IFS= read -r skill; do
        [[ -n "$skill" ]] && rf::skills::install_one "$skill" "$base" "$host_id" "$scope"
    done < <(rf::skills::list_upstream)

    rf::skills::reconcile_removed "$base" "$host_id" "$scope" || true
}

# rf::skills::reconcile_removed <base> <host_id> <scope>
# For each Roboflow-managed skill on disk under <base> whose name no longer
# appears upstream, back up and remove it.
rf::skills::reconcile_removed() {
    local base="$1" host_id="$2" scope="$3"
    [[ -d "$base" ]] || return 0

    local d skill sidecar
    for d in "$base"/*/; do
        [[ -d "$d" ]] || continue
        sidecar="$d.roboflow-install-manifest.json"
        [[ -f "$sidecar" ]] || continue
        skill="$(basename "$d")"
        # Was this one of ours and is it gone upstream? `grep -F -x` without
        # `-q` so grep drains the pipe — under `set -o pipefail` an early
        # `-q` exit triggers SIGPIPE and the pipeline reports failure.
        if rf::skills::list_upstream | grep -Fx -- "$skill" >/dev/null 2>&1; then
            continue
        fi
        if [[ "${RF_OPT_DRY_RUN:-0}" == "1" ]]; then
            rf::info "[dry-run] would remove obsolete skill $skill ($d)"
            continue
        fi
        local stamp bak
        stamp="$(date -u +%Y%m%dT%H%M%SZ)"
        bak="${d%/}.bak.$stamp"
        mv "${d%/}" "$bak"
        rf::warn "removed obsolete skill $skill (backup: $bak)"
        rf::manifest::remove "$host_id" "skill" "$scope" "$skill" || true
    done
}

# rf::skills::remove_all <base> <host_id> <scope>
# Uninstall — remove every Roboflow-managed skill under <base>.
rf::skills::remove_all() {
    local base="$1" host_id="$2" scope="$3"
    [[ -d "$base" ]] || return 0

    local d skill sidecar
    for d in "$base"/*/; do
        [[ -d "$d" ]] || continue
        sidecar="$d.roboflow-install-manifest.json"
        [[ -f "$sidecar" ]] || continue
        skill="$(basename "$d")"

        if [[ "${RF_OPT_DRY_RUN:-0}" == "1" ]]; then
            rf::info "[dry-run] would remove skill $skill ($d)"
            continue
        fi

        # Check for local edits and skip unless --force.
        local current_hash manifest_hash
        current_hash="$(rf::skills::content_hash "$d")"
        manifest_hash="$(rf::json::read_field "$sidecar" .content_hash 2>/dev/null | sed 's/^sha256://' || true)"
        if [[ -n "$manifest_hash" ]] && [[ "$current_hash" != "$manifest_hash" ]] \
           && [[ "${RF_OPT_FORCE:-0}" != "1" ]]; then
            rf::warn "skill $skill has local edits; not removing (use --force to override)"
            continue
        fi

        local stamp bak
        stamp="$(date -u +%Y%m%dT%H%M%SZ)"
        bak="${d%/}.bak.$stamp"
        mv "${d%/}" "$bak"
        rf::ok "removed skill $skill (backup: $bak)"
        rf::manifest::remove "$host_id" "skill" "$scope" "$skill" || true
    done
}
