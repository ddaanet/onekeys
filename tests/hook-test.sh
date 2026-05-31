#!/usr/bin/env bash
# Test harness for scripts/onekeys-hook.sh.
# Runs the hook under a throwaway HOME so the real ~/.claude is untouched.
set -uo pipefail

HOOK="$(cd "$(dirname "$0")/.." && pwd)/scripts/onekeys-hook.sh"
TEST_HOME="$(mktemp -d)"
trap 'rm -rf "$TEST_HOME"' EXIT
MAP_FILE="$TEST_HOME/.claude/onekeyers.txt"
fails=0

# run PROMPT -> sets OUT to the hook's stdout for that prompt.
run() {
    OUT="$(jq -cn --arg p "$1" '{prompt:$p}' | HOME="$TEST_HOME" bash "$HOOK")"
}

assert_contains() {
    if [[ "$OUT" == *"$1"* ]]; then
        echo "PASS: output contains '$1'"
    else
        echo "FAIL: expected output to contain '$1', got: '$OUT'"
        fails=$((fails + 1))
    fi
}

assert_empty() {
    if [[ -z "$OUT" ]]; then
        echo "PASS: empty output for this case"
    else
        echo "FAIL: expected empty output, got: '$OUT'"
        fails=$((fails + 1))
    fi
}

# Seeding: mapping absent, first run creates it with the 8 defaults.
[[ -e "$MAP_FILE" ]] && { echo "FAIL: map file should not exist yet"; fails=$((fails + 1)); }
run "c"
if [[ -f "$MAP_FILE" ]]; then
    echo "PASS: map file seeded on first run"
else
    echo "FAIL: map file was not seeded"
    fails=$((fails + 1))
fi
lines="$(grep -cve '^[[:space:]]*$' "$MAP_FILE" 2>/dev/null || echo 0)"
if [[ "$lines" -eq 8 ]]; then
    echo "PASS: seeded mapping has 8 entries"
else
    echo "FAIL: expected 8 seeded entries, got $lines"
    fails=$((fails + 1))
fi

# Plain-instruction expansion.
run "c"; assert_contains "Continue"
run "r"; assert_contains "Retry"
run "n"; assert_contains "Next?"
run "y"; assert_contains "Yes"
run "w"; assert_contains "What do you think?"

# Slash-command expansions, including case sensitivity (h vs H).
run "h"; assert_contains "/handoff:handoff"
run "H"; assert_contains "/handoff, /commit, /autoname"
run "t"; assert_contains "/autoname"

# A user-visible systemMessage echoes the expansion.
run "c"; assert_contains '"systemMessage":"onekeys: c → Continue"'

# Passthrough cases produce no output.
run "x"; assert_empty
run "hello"; assert_empty
run ""; assert_empty

# Whitespace is trimmed before matching.
run " c "; assert_contains "Continue"

if [[ "$fails" -eq 0 ]]; then
    echo "All tests passed."
    exit 0
else
    echo "$fails test(s) failed."
    exit 1
fi
