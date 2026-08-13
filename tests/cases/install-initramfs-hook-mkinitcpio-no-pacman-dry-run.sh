#!/bin/sh
# Case: --install-initramfs-hook --no-pacman-initramfs-hook --dry-run on a
# mkinitcpio-simulated host prints the mkinitcpio install-hook target path,
# does NOT mention the pacman trigger hook, and recommends the plain
# `mkinitcpio -P` regen command (no `-A modulejail-strip`, since the
# operator is expected to wire the hook into HOOKS in /etc/mkinitcpio.conf
# themselves). Does NOT write any file.
set -eu

CASE_NAME=install-initramfs-hook-mkinitcpio-no-pacman-dry-run
export CASE_NAME

# shellcheck source=tests/lib/case-env.sh disable=SC1091
. "$(dirname "$0")/../lib/case-env.sh"
# shellcheck source=tests/lib/assert.sh disable=SC1091
. "$REPO_ROOT/tests/lib/assert.sh"

trap 'rm -rf "$CASE_TMP"' EXIT INT HUP TERM

set +e
MODULEJAIL_INITRAMFS_BUILDER=mkinitcpio \
    "$MODULEJAIL_BIN" --install-initramfs-hook --no-pacman-initramfs-hook --dry-run \
    > "$CASE_TMP/stdout" 2> "$CASE_TMP/stderr"
rc=$?
set -e

assert_eq 0 "$rc" "mkinitcpio-no-pacman-dry-run-exit-code"

# The mkinitcpio install hook target is still announced.
assert_grep '^modulejail: dry-run: would write /etc/initcpio/install/modulejail-strip \(0755\)$' \
    "$CASE_TMP/stdout" mkinitcpio-no-pacman-dry-run-target-path

# The pacman trigger hook must NOT be announced.
if grep -q 'would write /usr/share/libalpm/hooks/95-modulejail-strip.hook' "$CASE_TMP/stdout"; then
    case_fail "dry-run announced pacman trigger hook despite --no-pacman-initramfs-hook"
fi

# The regen command is plain `mkinitcpio -P` (no `-A modulejail-strip`).
assert_grep 'mkinitcpio -P`$' \
    "$CASE_TMP/stdout" mkinitcpio-no-pacman-dry-run-regen-command
# And explicitly NOT the `-A modulejail-strip` form.
if grep -q 'mkinitcpio -P -- -A modulejail-strip' "$CASE_TMP/stdout"; then
    case_fail 'dry-run recommended backtick -A modulejail-strip despite --no-pacman-initramfs-hook'
fi

# The operator-facing manual HOOKS instruction must be present.
assert_grep 'manually append .modulejail-strip. to HOOKS in /etc/mkinitcpio.conf' \
    "$CASE_TMP/stdout" mkinitcpio-no-pacman-dry-run-manual-hooks-hint

if [ -e /etc/initcpio/install/modulejail-strip ]; then
    case_fail "--dry-run wrote the mkinitcpio install hook (should be no-op)"
fi

case_pass
