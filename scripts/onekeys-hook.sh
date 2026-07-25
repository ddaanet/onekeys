#!/usr/bin/env bash
# onekeys UserPromptSubmit hook.
#
# When the user's entire prompt is a single character that matches a key
# in ~/.claude/onekeyers.txt, inject additionalContext instructing Claude
# to treat the prompt as the mapped expansion. All other prompts pass
# through untouched (no output, exit 0).
#
# A UserPromptSubmit hook cannot rewrite the prompt or run a slash command
# itself; on exit 0 it can only add context. So the expansion is injected
# as authoritative user intent, and Claude acts on it -- invoking the
# matching command/skill itself for slash-command expansions.
set -euo pipefail

MAP_FILE="${HOME}/.claude/onekeyers.txt"
# BASE_FILE records the shipped defaults as of the last reconcile -- the
# common ancestor for the 3-way merge. SIDECAR holds an unresolved merge
# (with base markers) so the live MAP_FILE is never typed against markers.
BASE_FILE="${HOME}/.claude/onekeyers.base.txt"
SIDECAR="${MAP_FILE}.merge"
# NAG is set by reconcile when a conflict sidecar is (re)written, so main
# surfaces a one-time notice.
NAG=""

# print_defaults -> writes the shipped default mapping to stdout. Single
# source of truth for both seeding and reconciliation (the "OTHER" side of
# the 3-way merge).
print_defaults() {
    cat <<'EOF'
c Continue
r Retry
h /handoff:handoff
H /handoff, /commit
p List pending tasks, no tool use allowed.
w What do you think?
y Yes
EOF
}

# has_conflict_markers FILE -> succeeds if FILE still contains diff3 merge
# markers (an unresolved conflict).
has_conflict_markers() {
    grep -Eq '^(<<<<<<<|>>>>>>>|\|\|\|\|\|\|\|)' "$1"
}

# reconcile -> bring MAP_FILE in line with the shipped defaults without
# discarding the user's customizations. Replaces plain seed-if-absent.
#
# Inputs to the 3-way merge: MINE = MAP_FILE (live), OTHER = current
# shipped defaults, BASE = BASE_FILE (defaults at last reconcile). A clean
# merge is applied transparently; a conflict is written to SIDECAR with the
# base section intact (so the delta is legible) and the live file is left
# untouched -- the user resolves the sidecar, and the next run promotes it.
reconcile() {
    local other rc merged
    mkdir -p "$(dirname "$MAP_FILE")"
    other="$(mktemp)" || return 0
    print_defaults >"$other"

    if ! command -v diff3 >/dev/null 2>&1; then
        # No diff3 -> degrade to legacy seed-or-skip; never break the prompt.
        if [[ ! -e "$MAP_FILE" ]]; then
            cp "$other" "$MAP_FILE"
            cp "$other" "$BASE_FILE"
        fi
    elif [[ ! -e "$MAP_FILE" ]]; then
        # First ever run: seed live file and base together.
        cp "$other" "$MAP_FILE"
        cp "$other" "$BASE_FILE"
    elif [[ -e "$SIDECAR" ]]; then
        # A resolution is in flight. Promote it only once markers are gone.
        if ! has_conflict_markers "$SIDECAR"; then
            mv "$SIDECAR" "$MAP_FILE"
            cp "$other" "$BASE_FILE"
        fi
    elif [[ ! -e "$BASE_FILE" ]]; then
        # Live file predates base tracking: adopt it as authoritative.
        cp "$other" "$BASE_FILE"
    elif cmp -s "$BASE_FILE" "$other"; then
        : # Defaults unchanged since last reconcile -- nothing to do.
    else
        # Defaults changed: 3-way merge.
        set +e
        merged="$(diff3 -m "$MAP_FILE" "$BASE_FILE" "$other")"
        rc=$?
        set -e
        if [[ "$rc" -eq 0 ]]; then
            # Clean merge -> apply transparently, advance base.
            printf '%s\n' "$merged" >"$MAP_FILE"
            cp "$other" "$BASE_FILE"
            rm -f "$SIDECAR"
        elif [[ "$rc" -eq 1 ]]; then
            # Conflict -> sidecar (with base markers); leave MINE and BASE.
            printf '%s\n' "$merged" >"$SIDECAR"
            NAG=1
        fi
        # rc >= 2: diff3 trouble -> fail safe, change nothing.
    fi

    rm -f "$other"
}

# lookup KEY -> prints the expansion for a single-character KEY, or
# returns 1 if no entry matches.
lookup() {
    local key="$1" line k
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        [[ "$line" == *" "* ]] || continue   # needs key<space>expansion
        k="${line%% *}"
        [[ "${#k}" -eq 1 ]] || continue       # keys are single chars
        if [[ "$k" == "$key" ]]; then
            printf '%s' "${line#* }"
            return 0
        fi
    done <"$MAP_FILE"
    return 1
}

main() {
    local input prompt trimmed expansion ctx msg notice matched
    input="$(cat)"
    prompt="$(jq -r '.prompt // ""' <<<"$input")"

    # Trim leading and trailing whitespace.
    trimmed="${prompt#"${prompt%%[![:space:]]*}"}"
    trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"

    # Only single-character prompts are candidates for expansion.
    [[ "${#trimmed}" -eq 1 ]] || exit 0

    reconcile
    if expansion="$(lookup "$trimmed")"; then
        matched=1
    else
        matched=0
    fi

    # Nothing to say: no mapping matched and no conflict to report.
    [[ "$matched" -eq 1 || -n "$NAG" ]] || exit 0

    ctx=""
    msg=""
    if [[ "$matched" -eq 1 ]]; then
        ctx="The user's prompt is the onekeys shorthand '${trimmed}', which expands to: ${expansion}. Act on the expansion as if the user had typed it; if it is a slash command, run that command."
        # systemMessage surfaces the expansion to the user so the shorthand
        # is not silent; additionalContext is what Claude acts on.
        msg="onekeys: ${trimmed} → ${expansion}"
    fi

    # A reconcile conflict rides the same systemMessage, once.
    if [[ -n "$NAG" ]]; then
        notice="onekeys: shipped defaults changed and conflict with your edits — resolve ${SIDECAR}"
        if [[ -n "$msg" ]]; then msg="${msg} — ${notice}"; else msg="${notice}"; fi
    fi

    if [[ -n "$ctx" ]]; then
        jq -cn --arg ctx "$ctx" --arg msg "$msg" \
            '{systemMessage: $msg, hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}'
    else
        jq -cn --arg msg "$msg" '{systemMessage: $msg}'
    fi
}

main
