#!/bin/sh
# Case: a whitelist file containing only comments and blank lines (no
# module names) is accepted (exit 0). It contributes no entries, so the
# generated blacklist must be byte-identical to a run without
# --whitelist-file at all (i.e. the file is a no-op).
set -eu

CASE_NAME=whitelist-file-comments-and-blanks
export CASE_NAME

# shellcheck source=tests/lib/case-env.sh disable=SC1091
. "$(dirname "$0")/../lib/case-env.sh"
# shellcheck source=tests/lib/case-tree.sh disable=SC1091
. "$REPO_ROOT/tests/lib/case-tree.sh"
# shellcheck source=tests/lib/assert.sh disable=SC1091
. "$REPO_ROOT/tests/lib/assert.sh"

trap 'rm -rf "$CASE_TMP"' EXIT INT HUP TERM

WL=$CASE_TMP/whitelist.txt
{
    printf '# This whitelist file is intentionally empty.\n'
    printf '# Operators may flesh it out later.\n'
    printf '\n'
    printf '  \n'   # blank-with-spaces line
    printf '\t\n'   # blank-with-tab line
    printf '# trailing comment\n'
} > "$WL"
chmod 0644 "$WL"

OUT_WITH=$CASE_TMP/out-with.conf
OUT_WITHOUT=$CASE_TMP/out-without.conf

# Run WITH the no-op whitelist file.
"$MODULEJAIL_BIN" --whitelist-file "$WL" -o "$OUT_WITH" > "$CASE_TMP/stdout-with" 2> "$CASE_TMP/stderr-with" || \
    case_fail "modulejail (with WL) exited $? (expected 0); stderr=$(cat "$CASE_TMP/stderr-with")"

# Run WITHOUT --whitelist-file.
"$MODULEJAIL_BIN" -o "$OUT_WITHOUT" > "$CASE_TMP/stdout-without" 2> "$CASE_TMP/stderr-without" || \
    case_fail "modulejail (no WL) exited $? (expected 0); stderr=$(cat "$CASE_TMP/stderr-without")"

# Both outputs MUST be byte-identical EXCEPT for the invocation header,
# which legitimately differs because the two runs use different args
# (--whitelist-file PATH vs no flag). Strip the invocation line before the
# byte-identity check; the fingerprint, the install-line annotation, and
# every install body line MUST match - the fingerprint hashes the canonical
# sorted whitelist content, so a no-op file MUST produce the same
# fingerprint as no file at all.
grep -v '^# invocation:' "$OUT_WITH" > "$CASE_TMP/with.body"
grep -v '^# invocation:' "$OUT_WITHOUT" > "$CASE_TMP/without.body"
assert_cmp "$CASE_TMP/with.body" "$CASE_TMP/without.body"

case_pass
