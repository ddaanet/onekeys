#!/usr/bin/env bash
# Test harness for scripts/onekeys-hook.sh.
# Runs the hook under a throwaway HOME so the real ~/.claude is untouched.
set -uo pipefail

HOOK="$(cd "$(dirname "$0")/.." && pwd)/scripts/onekeys-hook.sh"
TEST_HOME="$(mktemp -d)"
trap 'rm -rf "$TEST_HOME"' EXIT
MAP_FILE="$TEST_HOME/.claude/onekeyers.txt"
BASE_FILE="$TEST_HOME/.claude/onekeyers.base.txt"
SIDECAR="$MAP_FILE.merge"
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

# File assertions for the reconcile cases. FILE PATTERN LABEL.
assert_file_has() {
    if grep -Fq "$2" "$1" 2>/dev/null; then
        echo "PASS: $3"
    else
        echo "FAIL: $3 ($1 lacks '$2')"
        fails=$((fails + 1))
    fi
}
assert_file_lacks() {
    if grep -Fq "$2" "$1" 2>/dev/null; then
        echo "FAIL: $3 ($1 unexpectedly has '$2')"
        fails=$((fails + 1))
    else
        echo "PASS: $3"
    fi
}
assert_path_present() {
    if [[ -e "$1" ]]; then echo "PASS: $2"; else echo "FAIL: $2 ($1 missing)"; fails=$((fails + 1)); fi
}
assert_path_absent() {
    if [[ -e "$1" ]]; then echo "FAIL: $2 ($1 exists)"; fails=$((fails + 1)); else echo "PASS: $2"; fi
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
# The base (merge ancestor) is seeded alongside the live mapping.
assert_path_present "$BASE_FILE" "base file seeded alongside mapping"

# Snapshot the pristine defaults (== OTHER) for the reconcile cases below.
# None of the intervening cases mutate the mapping, so this stays valid.
DEFAULTS="$TEST_HOME/defaults.snapshot"
cp "$MAP_FILE" "$DEFAULTS"

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

# --- Reconcile: keep the mapping current with shipped defaults ---
# OTHER (the shipped defaults) is whatever the script bakes in; the cases
# below pre-write MINE/BASE/SIDECAR under the temp HOME to drive each branch.

# Cheap no-op: defaults unchanged since last reconcile -> custom line kept,
# nothing merged, no sidecar.
cp "$DEFAULTS" "$MAP_FILE"; printf 'z Foo\n' >>"$MAP_FILE"
cp "$DEFAULTS" "$BASE_FILE"
rm -f "$SIDECAR"
run "c"
assert_file_has "$MAP_FILE" "z Foo" "no-op preserves the user's custom line"
assert_path_absent "$SIDECAR" "no-op writes no sidecar"

# Clean merge (mainline): shipped defaults re-add a line the user's base
# lacked; a non-overlapping custom line is preserved. Applied transparently.
grep -Fv 't /autoname' "$DEFAULTS" >"$BASE_FILE"     # base predates the t key
cp "$BASE_FILE" "$MAP_FILE"; printf 'z Foo\n' >>"$MAP_FILE"
rm -f "$SIDECAR"
run "c"
assert_file_has "$MAP_FILE" "t /autoname" "clean merge pulls in the new default"
assert_file_has "$MAP_FILE" "z Foo" "clean merge keeps the custom line"
assert_path_absent "$SIDECAR" "clean merge writes no sidecar"
assert_file_has "$BASE_FILE" "t /autoname" "clean merge advances the base"

# Conflict: base, live, and shipped default all differ on the same key.
# diff3 conflicts; the sidecar must carry the base section (option b).
sed 's/^w .*/w BASEW/' "$DEFAULTS" >"$BASE_FILE"
sed 's/^w .*/w MINEW/' "$DEFAULTS" >"$MAP_FILE"
rm -f "$SIDECAR"
run "c"
assert_path_present "$SIDECAR" "conflict writes a sidecar"
assert_file_has "$SIDECAR" "|||||||" "sidecar carries the base section"
assert_file_has "$SIDECAR" "BASEW" "sidecar shows the base line (legible delta)"
assert_file_has "$MAP_FILE" "w MINEW" "conflict leaves the live file untouched"
assert_file_lacks "$MAP_FILE" "<<<<<<<" "conflict puts no markers in the live file"
assert_file_has "$BASE_FILE" "w BASEW" "conflict does not advance the base"
assert_contains "conflict with your edits"

# Pending conflict (sidecar still has markers): silent, untouched, no re-nag.
run "c"
assert_file_has "$MAP_FILE" "w MINEW" "pending conflict leaves the live file untouched"
assert_file_lacks "$MAP_FILE" "<<<<<<<" "pending conflict puts no markers in the live file"
if [[ "$OUT" == *"conflict with your edits"* ]]; then
    echo "FAIL: pending conflict re-nags"; fails=$((fails + 1))
else
    echo "PASS: pending conflict is silent"
fi

# Resolution promotion: a marker-free sidecar is promoted to the live file
# and the base advances. (Base still differs from defaults going in.)
sed 's/^w .*/w RESOLVED/' "$DEFAULTS" >"$SIDECAR"
run "c"
assert_path_absent "$SIDECAR" "resolved sidecar is consumed"
assert_file_has "$MAP_FILE" "w RESOLVED" "resolution is promoted to the live file"
# Base went in as the BASEW variant; advancing it makes it the defaults again.
assert_file_has "$BASE_FILE" "What do you think?" "promotion advances the base to defaults"
assert_file_lacks "$BASE_FILE" "w BASEW" "promotion replaces the stale base"

# Migration: live file present but base absent -> adopt live as
# authoritative (create base, no merge, no sidecar).
printf 'q Custom\n' >"$MAP_FILE"
rm -f "$BASE_FILE" "$SIDECAR"
run "c"
assert_path_present "$BASE_FILE" "migration creates the base"
assert_file_has "$MAP_FILE" "q Custom" "migration leaves the live file untouched"
mlines="$(grep -cve '^[[:space:]]*$' "$MAP_FILE" 2>/dev/null || echo 0)"
if [[ "$mlines" -eq 1 ]]; then
    echo "PASS: migration does not merge defaults into the live file"
else
    echo "FAIL: migration changed the live file (expected 1 line, got $mlines)"
    fails=$((fails + 1))
fi
assert_path_absent "$SIDECAR" "migration writes no sidecar"

if [[ "$fails" -eq 0 ]]; then
    echo "All tests passed."
    exit 0
else
    echo "$fails test(s) failed."
    exit 1
fi
