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

seed_if_absent() {
    [[ -e "$MAP_FILE" ]] && return 0
    mkdir -p "$(dirname "$MAP_FILE")"
    cat >"$MAP_FILE" <<'EOF'
c Continue
r Retry
h /handoff:handoff
H /handoff, /commit, /autoname
t /autoname
n Next?
w What do you think?
y Yes
EOF
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
    local input prompt trimmed expansion ctx
    input="$(cat)"
    prompt="$(jq -r '.prompt // ""' <<<"$input")"

    # Trim leading and trailing whitespace.
    trimmed="${prompt#"${prompt%%[![:space:]]*}"}"
    trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"

    # Only single-character prompts are candidates for expansion.
    [[ "${#trimmed}" -eq 1 ]] || exit 0

    seed_if_absent
    expansion="$(lookup "$trimmed")" || exit 0

    ctx="The user's prompt is the onekeys shorthand '${trimmed}', which expands to: ${expansion}. Act on the expansion as if the user had typed it; if it is a slash command, run that command."
    # systemMessage surfaces the expansion to the user so the shorthand is
    # not silent; additionalContext is what Claude acts on.
    msg="onekeys: ${trimmed} → ${expansion}"
    jq -cn --arg ctx "$ctx" --arg msg "$msg" \
        '{systemMessage: $msg, hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}'
}

main
