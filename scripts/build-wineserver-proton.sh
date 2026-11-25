#!/usr/bin/env bash
# Build a drop-in wineserver (O(log n) mapped-view lookups) for Proton / GE-Proton, without rebuilding Wine.
#
# Why this exists next to build-wineserver.sh: that one needs nixpkgs (WINE_ATTR) and builds against nixpkgs'
# wine-staging. A Proton user has neither nix nor that tree, and the server binary MUST match the client's Wine
# version - so this script builds from the Wine source the chosen Proton release was built from.
#
# Usage:
#   scripts/build-wineserver-proton.sh <path-to-proton-dir> [wine-source-tarball-or-git-dir]
#
#   <path-to-proton-dir>   e.g. ~/.steam/root/compatibilitytools.d/GE-Proton11-12
#                          (must contain files/bin/wineserver)
#   [wine source]          optional. A directory or .tar.xz of the Wine tree that release was built from.
#                          Without it the script only probes and tells you what to fetch.
#
# What it does: applies patches/wine/upstream/*.patch (the version-neutral variant of our rbtree patch), configures
# with --enable-win64, builds ONLY server/wineserver, and writes the result next to the original. It does NOT swap
# the binary - the last line tells you the two commands that do, so you can keep a way back.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
P=$ROOT/patches/wine/upstream

proton=${1:?usage: $0 <proton-dir> [wine-source-dir-or-tarball]}
proton=$(realpath "$proton")
orig=$proton/files/bin/wineserver
[ -x "$orig" ] || { echo "not a Proton dir: $orig missing or not executable" >&2; exit 1; }
srcarg=${2:-}

echo "Proton:        $proton"
echo "its wineserver: $($orig --version 2>/dev/null || echo '(--version said nothing)')"
if [ -n "$srcarg" ] && [ -d "$srcarg" ]; then
    echo "Wine source:   $srcarg (directory)"
elif [ -n "$srcarg" ] && [ -f "$srcarg" ]; then
    echo "Wine source:   $srcarg (archive)"
else
    cat <<EOF

No Wine source given, so nothing was built. Find the Wine tree this Proton release was built from:

  GE-Proton:      the release notes of GloriousEggroll/proton-ge-custom name the Wine version, and its build
                  clones wine at that tag. Use the SAME tag, not whatever is newest:
                    git clone --depth 1 --branch <tag> https://github.com/Wine-Staging/wine-staging   (or wine-mirror/wine)
                  A tarball of the same tag is better than a clone: it pins the version exactly.
  Valve Proton:   the proton repo vendors wine as a submodule; use the version the proton tag pins.

Then re-run:
  $0 "$proton" /path/to/wine-<version>

Build requirements (Fedora: dnf install gcc make flex bison perl-devel; Debian/Ubuntu: build-essential flex bison):
only the server is compiled, so no mingw, no X, no Vulkan, no OpenGL headers are needed (the script passes
--without-mingw for that reason; on x86_64/arm Linux Wine rejects a build without it) - the --without-x/freetype/gnutls/
wayland/vulkan/opengl flags are not cosmetic either: without them configure insists on Xlib, Wayland and Vulkan
development packages before it will build a SERVER-only target.

Why the version matters: this patch only adds an index inside wineserver (it changes no request, reply or wire
message), so if it compiles it cannot desynchronise Wine's client/server protocol. What DOES break is a server binary
from a different Wine version than the client: the game then sits black for minutes. Building from your own Proton's
Wine tree is what avoids that.
EOF
    exit 2
fi

tmp=$(mktemp -d); trap 'chmod -R u+w "$tmp" 2>/dev/null; rm -rf "$tmp"' EXIT
if [ -d "$srcarg" ]; then
    # Work on a copy: patching and building in the user's tree would make a second run fail
    # ("previously applied") and edits files they may want pristine. A git tree is copied without .git.
    src=$tmp/src; mkdir -p "$src"
    ( cd "$srcarg" && tar -cf - --exclude=.git --exclude=build . ) | tar -xf - -C "$src"
    echo "Wine source:   $srcarg (copied to a scratch tree)"
else
    tar -xf "$srcarg" -C "$tmp"; src=$(find "$tmp" -maxdepth 1 -type d -name 'wine-*' | head -1)
    echo "Wine source:   $srcarg (extracted)"
fi
[ -f "$src/configure" ] || { echo "no configure in $src - is that a Wine source tree?" >&2; exit 1; }

for p in "$P"/*.patch; do
    echo "applying $(basename "$p")"
    if ! patch -d "$src" -p1 --forward < "$p"; then
        cat <<EOF >&2

patch did not apply cleanly. Send upstream the .rej files and \`git -C "$src" describe\` if it is a git tree:
  find "$src" -name '*.rej'
The patch is version-anchored; a different Wine tag usually needs a one-line rebase, not a new port.
EOF
        exit 3
    fi
done

build=$tmp/build; mkdir -p "$build"; cd "$build"
echo "configuring (server only)"
"$src/configure" --enable-win64 --without-mingw --without-x --without-freetype --without-gnutls \
    --without-wayland --without-vulkan --without-opengl --disable-tests > configure.log 2>&1 \
    || { echo "configure failed, see $build/configure.log" >&2; tail -5 configure.log >&2; exit 4; }
echo "building server/wineserver"
make -j"${JOBS:-4}" server/wineserver > make.log 2>&1 \
    || { echo "make failed, see $build/make.log" >&2; tail -20 make.log >&2; exit 5; }

out=$proton/files/bin/wineserver-patched
install -m755 server/wineserver "$out"
strip "$out" || true
cp -n "$orig" "$proton/files/bin/wineserver.orig" 2>/dev/null || true

# wineserver finds l_intl.nls relative to its own location (../share/wine/nls, compiled in). Proton ships that
# already, so it works beside files/bin/wineserver - but verify, because a server that cannot load l_intl.nls
# starts and then quietly gives up, and Wine falls back to the stock server: the patch looks like it did nothing.
if [ -f "$proton/files/share/wine/nls/l_intl.nls" ]; then
    echo "nls:        $proton/files/share/wine/nls (Proton's own)"
else
    echo "nls:        NOT found at $proton/files/share/wine/nls - linking it from the Wine source"
    mkdir -p "$proton/files/share/wine"
    # Link the ORIGINAL tree, not our scratch copy: the copy is deleted on exit, and a dangling link means
    # the server silently fails to load l_intl.nls and Wine falls back to the stock server.
    if [ -d "$srcarg" ]; then nlsfrom=$(realpath "$srcarg")/nls; else nlsfrom=$src/nls; fi
    ln -sfn "$nlsfrom" "$proton/files/share/wine/nls"
    if [ -n "${PROTON_NLS:-}" ]; then ln -sfn "$PROTON_NLS" "$proton/files/share/wine/nls"; fi
    if [ ! -f "$proton/files/share/wine/nls/l_intl.nls" ]; then
        echo "WARNING: no l_intl.nls reachable. Point PROTON_NLS at a directory holding it (any Wine or Proton" >&2
        echo "         install has share/wine/nls/l_intl.nls) and re-run, or the patched server will not start." >&2
    fi
fi

cat <<EOF

built: $out

Check it before you play (our test binary, ships with the kit):
  wine test/viewbench.exe 40000
Expected with the patched server: map ~1.5 s, query ~0.07 s, unmap well under 1 s, "0 correctness errors".
Stock numbers are 18.1 s / 1.33 s - if you see those, the stock server ran, not this one.

To use it (keeps the original as wineserver.orig):
  cd "$proton/files/bin" && mv wineserver wineserver.stock && cp wineserver-patched wineserver

To undo:
  cd "$proton/files/bin" && mv wineserver.stock wineserver

Do NOT use the WINESERVER environment variable to select a server: this Wine does not honour it for that. And a
Steam/Proton launch starts and stops its own server per prefix, so replacing the binary is the only reliable route.

Expectation setting: this fixes LONG STALLS (boot, menus, streaming - map/unmap/query over tens of thousands of
views), NOT the frame time. We measured the server at 3-7% of one core in game.
EOF
