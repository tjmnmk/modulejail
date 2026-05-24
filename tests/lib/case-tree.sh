#!/bin/sh
# Synthetic representative-universe builder for host-local test cases.
# Sourced (NOT executed) by each case that wants the small synthetic
# kernel-module tree (13 representative + 50 dummy padding modules) and
# the matching fake /proc/modules pinning 7 loaded entries.
#
# Dependency contract: this file consumes CASE_TMP, which is set by
# tests/lib/case-env.sh. Source ORDER is mandatory:
#
#   . "$REPO_ROOT/tests/lib/case-env.sh"   # sets CASE_TMP first
#   . "$REPO_ROOT/tests/lib/case-tree.sh"  # consumes CASE_TMP
#
# This file is NOT sourced by tests/cases/v1.1.4-regression.sh - that
# case builds its own 6474-entry universe inline from the canned
# tests/fixtures/v1.1.4-regression/modules-list and uses CASE_TMP's
# layout under a different convention (lo/ + uc/ sharding for APFS
# case-insensitivity).
#
# Outputs (exported for the modulejail invocation):
#   MODULEJAIL_MODULES_ROOT - synthetic /lib/modules root
#   MODULEJAIL_KVER         - pinned synthetic kernel version
#   MODULEJAIL_PROC_MODULES - path to fake /proc/modules
#
# This file does NOT call `set -eu` (it is .-sourced into the caller's
# shell which already has it) and does NOT install an EXIT trap
# (case-env.sh's centralized trap covers CASE_TMP cleanup).

CASE_KVER=6.99.0-case
CASE_MODULES_ROOT=$CASE_TMP/lib/modules
CASE_TREE=$CASE_MODULES_ROOT/$CASE_KVER/kernel
mkdir -p "$CASE_TREE/fs" "$CASE_TREE/net" "$CASE_TREE/drivers" "$CASE_TREE/crypto"

# Representative universe: a handful across the four .ko* suffix variants
# plus padding to keep the >99% sanity guard from tripping on the small
# keep-set (loaded ~7 entries + baseline ~55 + whitelist additions).
touch \
    "$CASE_TREE/fs/ext4.ko.zst" \
    "$CASE_TREE/fs/btrfs.ko.zst" \
    "$CASE_TREE/fs/xfs.ko.xz" \
    "$CASE_TREE/fs/vfat.ko.gz" \
    "$CASE_TREE/net/sctp.ko.zst" \
    "$CASE_TREE/net/netfilter.ko.zst" \
    "$CASE_TREE/net/nft_compat.ko" \
    "$CASE_TREE/drivers/e1000e.ko" \
    "$CASE_TREE/drivers/virtio_net.ko.gz" \
    "$CASE_TREE/drivers/vfio_pci.ko.zst" \
    "$CASE_TREE/drivers/usb_storage.ko.zst" \
    "$CASE_TREE/crypto/aes_generic.ko.zst" \
    "$CASE_TREE/crypto/sha256_generic.ko"

i=1
while [ "$i" -le 50 ]; do
    touch "$CASE_TREE/drivers/dummy_$i.ko.zst"
    i=$((i + 1))
done

CASE_PROC=$CASE_TMP/proc-modules
{
    printf '%s 16384 1 - Live 0x0000000000000000\n' ext4
    printf '%s 16384 1 - Live 0x0000000000000000\n' btrfs
    printf '%s 16384 1 - Live 0x0000000000000000\n' xfs
    printf '%s 16384 1 - Live 0x0000000000000000\n' e1000e
    printf '%s 16384 1 - Live 0x0000000000000000\n' virtio_net
    printf '%s 16384 1 - Live 0x0000000000000000\n' usb_storage
    printf '%s 16384 1 - Live 0x0000000000000000\n' aes_generic
} > "$CASE_PROC"

MODULEJAIL_MODULES_ROOT=$CASE_MODULES_ROOT
MODULEJAIL_KVER=$CASE_KVER
MODULEJAIL_PROC_MODULES=$CASE_PROC
export MODULEJAIL_MODULES_ROOT MODULEJAIL_KVER MODULEJAIL_PROC_MODULES
