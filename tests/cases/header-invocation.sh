#!/bin/sh
# Case: the `# invocation:` header line records the exact argv used to
# produce the blacklist, with POSIX-canonical single-quote encoding so the
# recorded line is copy-paste replayable. Covers four argv shapes:
#
#   1. Plain args - no special characters; no quoting applied.
#   2. Empty args - the literal empty string is emitted as `''`.
#   3. Args containing whitespace - wrapped in single quotes.
#   4. Args containing single quotes - encoded with the canonical `'\''`
#      idiom (close-quote, escaped-apostrophe, open-quote).
#
# The four-backslash escape in the single-quote assertion is intentional:
# shell strips two of them, grep BRE keeps the remaining `\\` as a literal
# backslash match, which is exactly what the recorded line contains.
set -eu

CASE_NAME=header-invocation
export CASE_NAME

# shellcheck source=tests/lib/case-env.sh disable=SC1091
. "$(dirname "$0")/../lib/case-env.sh"
# shellcheck source=tests/lib/case-tree.sh disable=SC1091
. "$REPO_ROOT/tests/lib/case-tree.sh"
# shellcheck source=tests/lib/assert.sh disable=SC1091
. "$REPO_ROOT/tests/lib/assert.sh"

trap 'rm -rf "$CASE_TMP"' EXIT INT HUP TERM

OUT=$CASE_TMP/out.conf
"$MODULEJAIL_BIN" -o "$OUT" > "$CASE_TMP/stdout" 2> "$CASE_TMP/stderr" || \
    case_fail "modulejail exited $? (expected 0); stderr=$(cat "$CASE_TMP/stderr")"

# Header invocation test plain args
assert_grep "^# invocation: $MODULEJAIL_BIN -o $OUT$" \
    "$OUT" header-invocation-plain-args

"$MODULEJAIL_BIN" --whitelist-file '' -o "$OUT" > "$CASE_TMP/stdout" 2> "$CASE_TMP/stderr" || \
    case_fail "modulejail exited $? (expected 0); stderr=$(cat "$CASE_TMP/stderr")"

# Header invocation test empty args
assert_grep "^# invocation: $MODULEJAIL_BIN --whitelist-file '' -o $OUT$" \
    "$OUT" header-invocation-empty-args

OUT="$CASE_TMP/out put.conf"
"$MODULEJAIL_BIN" -o "$OUT" > "$CASE_TMP/stdout" 2> "$CASE_TMP/stderr" || \
    case_fail "modulejail exited $? (expected 0); stderr=$(cat "$CASE_TMP/stderr")"

# Header invocation test args with spaces
assert_grep "^# invocation: $MODULEJAIL_BIN -o '$OUT'$" \
    "$OUT" header-invocation-args-with-spaces

OUT="$CASE_TMP/out'put.conf"
"$MODULEJAIL_BIN" -o "$OUT" > "$CASE_TMP/stdout" 2> "$CASE_TMP/stderr" || \
    case_fail "modulejail exited $? (expected 0); stderr=$(cat "$CASE_TMP/stderr")"

# Header invocation test args with single quotes
assert_grep "^# invocation: $MODULEJAIL_BIN -o '$CASE_TMP/out'\\\\''put.conf'$" \
    "$OUT" header-invocation-args-with-single-quotes

case_pass
