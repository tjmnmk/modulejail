# AUR packaging

This directory holds the canonical `PKGBUILD` for the Arch User Repository
package `modulejail`. The PKGBUILD is tracked in this repo so it is reviewable
in-tree alongside the `.deb` and `.rpm` packaging.

The published AUR git repo (`ssh://aur@aur.archlinux.org/modulejail.git`) is a
publishing-only mirror: `PKGBUILD`, `.SRCINFO`, and `LICENSE` are pushed there.

## Two-license arrangement

This directory has **two different licenses** in play, which is normal for
AUR submissions but worth being explicit about:

- **The PKGBUILD itself (the *recipe*)**: 0BSD, declared via the
  `SPDX-License-Identifier: 0BSD` header in `PKGBUILD` and the full text
  in `LICENSE` next to it. This is the [Arch sources-license recommendation][1]
  and a prerequisite for any future promotion of this package from AUR
  into an official Arch repository (`extra`).
- **The modulejail program itself**: GPL-3.0-only, declared via the
  `license=('GPL-3.0-only')` field in `PKGBUILD`. The upstream license
  text lives in `LICENSE` at the repository root; the AUR package
  installs it at `/usr/share/licenses/modulejail/LICENSE` on user
  systems.

The 0BSD applies *only* to the packaging recipe so anyone can vendor
the PKGBUILD into AUR helpers, mirrors, or templates without friction.
It does not, and cannot, change the modulejail program's GPL-3.0-only
licensing.

[1]: https://wiki.archlinux.org/title/Arch_package_guidelines#Package_sources_licenses

## Publishing to AUR

Prerequisite (one-time): SSH key registered at
<https://aur.archlinux.org/account>.

### The normal flow: `scripts/publish-aur.sh`

For a tagged release, the entire AUR publish is one command after
`git push --tags`:

```sh
./scripts/publish-aur.sh
```

The script reads the target version from the modulejail script's
`VERSION` constant, verifies the GitHub release tarball is reachable,
computes the sha256 locally, updates `packaging/aur/PKGBUILD`,
regenerates `.SRCINFO` on a remote docker host (default
`ubuntu-wifi`), clones or refreshes the AUR git repo into a scratch
dir, and pushes. Idempotent and safe to re-run.

Flags:

- `--pkgrel-bump` - keep pkgver, increment pkgrel by 1. Use for
  packaging-only changes (e.g. adding a `conflicts=` line, fixing a
  dependency declaration). Same release tarball, new `.pkgrel`.
- `--no-bump` - publish the PKGBUILD exactly as it sits on disk, no
  modification. Use when retrying after a partial failure where the
  bump already happened locally.
- `--dry-run` - run everything except the final `git push` to AUR.

The script regenerates `.SRCINFO` via docker on a remote host because
`makepkg` is not available on macOS. Override via
`REMOTE_BUILD_HOST=somehost ./scripts/publish-aur.sh` if you want a
different docker host.

### Optional: auto-publish on tag push

If you want AUR sync to happen automatically when you push a `v*` tag
to GitHub (no separate `./scripts/publish-aur.sh` invocation), activate
the `pre-push` hook in this repo:

```sh
# One-time, per checkout:
git config core.hooksPath scripts/hooks
```

After activation, `git push origin v1.2.5` triggers a backgrounded
polling process that waits for the GitHub tarball to appear and then
runs `publish-aur.sh`. Logs go to `/tmp/modulejail-aur-publish.log`.
See `scripts/hooks/pre-push` for the mechanism and recovery notes
(it handles the "AUR push happens before GitHub push completes"
ordering issue).

### Manual flow (if you ever need it)

The script above is the canonical path. The manual sequence is
preserved here in case the script is unavailable or you want to do
something the script doesn't support:

```sh
cd packaging/aur

# 1. Bump pkgver, reset pkgrel=1. Edit PKGBUILD by hand.

# 2. Refresh sha256 (committed PKGBUILD always carries real sha256,
#    never SKIP).
updpkgsums

# 3. Smoke-test locally on Arch (or in the container, see next section).
makepkg -si

# 4. Regenerate .SRCINFO.
makepkg --printsrcinfo > .SRCINFO

# 5. Commit the in-repo PKGBUILD bump.
git add PKGBUILD       # .SRCINFO is publish-only; not tracked in this repo
git commit -m "release(aur): bump PKGBUILD to vX.Y.Z"

# 6. Mirror PKGBUILD + .SRCINFO + LICENSE into a checkout of the AUR
#    git repo, commit, push. First time only:
#      git clone ssh://aur@aur.archlinux.org/modulejail.git /tmp/aur-publish
cp PKGBUILD .SRCINFO LICENSE /tmp/aur-publish/
cd /tmp/aur-publish
git add PKGBUILD .SRCINFO LICENSE
git commit -m "modulejail X.Y.Z"
git push
```

## Container smoke test (non-Arch host)

`scripts/publish-aur.sh` uses essentially this same docker-on-remote
recipe internally. If you want to invoke a standalone smoke build
(e.g. to validate a hand-edited PKGBUILD before letting the script
push it), here it is:

```sh
# Stage the PKGBUILD into a scratch dir on a docker-equipped host.
ssh some-linux-host 'mkdir -p /tmp/aur-smoke'
scp PKGBUILD some-linux-host:/tmp/aur-smoke/

ssh some-linux-host 'sudo docker run --rm -v /tmp/aur-smoke:/build archlinux:latest \
  /bin/bash -c "
    set -eu
    pacman -Syu --noconfirm --needed base-devel git pacman-contrib sudo
    useradd -m builder
    echo \"builder ALL=(ALL) NOPASSWD: ALL\" > /etc/sudoers.d/builder
    chown -R builder:builder /build
    sudo -u builder bash -lc \"cd /build && updpkgsums && \
      makepkg --printsrcinfo > .SRCINFO && \
      makepkg -s --noconfirm\"
  "'
```

A successful run prints `Finished making: modulejail X.Y.Z-N` and
leaves the `.pkg.tar.zst` in `/tmp/aur-smoke/` on the remote host.

## Notes

- `arch=('any')` is correct: modulejail is pure POSIX shell, no native code.
- `depends=('kmod')` covers `lsmod` and `modprobe`. Everything else
  (POSIX shell, coreutils, sed, awk) is in `base`, which AUR does not
  require declaring.
- `optdepends=('util-linux: logger(1)')` is a documentation gesture;
  `util-linux` itself is in `base` on every standard Arch install. Kept
  because minimal containers may strip it.
- The man page is templated (`man/modulejail.8.in`). The PKGBUILD does the
  same `__VERSION__` substitution that `packaging/build.sh` does for the
  `.deb` and `.rpm` builds, kept as a single `sed` line in `package()` for
  inspectability.
- The committed `sha256sums` is always the real checksum of the
  referenced release tarball. `SKIP` is never acceptable in this
  PKGBUILD (that pattern is for `-git` tracking flavors that pull
  HEAD, which this package does not). Run `updpkgsums` after every
  `pkgver` bump and before committing.
