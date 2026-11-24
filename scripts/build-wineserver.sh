#!/usr/bin/env bash
# Build a drop-in wineserver (O(log n) mapped-view lookups) for nixpkgs
# wineWow64Packages.stagingFull, without rebuilding the rest of Wine.
# Usage: scripts/build-wineserver.sh [outdir]   -> work/wineserver/bin/wineserver (scripts/run.sh picks it up)
# Run it with:  WINEPREFIX=P wineserver -k; WINEPREFIX=P <outdir>/bin/wineserver -p20; then start wine as usual.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd); W=${WORK:-$ROOT/work}; P=$ROOT/patches/wine
out=$(realpath -m "${1:-$W/wineserver}")
attr=${WINE_ATTR:-nixpkgs#wineWow64Packages.stagingFull}
tmp=$(mktemp -d); trap '[ $? = 0 ] && { chmod -R u+w "$tmp"; rm -rf "$tmp"; } || echo "failed, see $tmp" >&2' EXIT
cd "$tmp"
# unpack + nixpkgs patches + wine-staging patchset, exactly as the package does
nix develop "$attr" --command bash -c 'set -e; source "$stdenv/setup"; unpackPhase; cd "$sourceRoot"; patchPhase' > prep.log 2>&1
src=$(find "$tmp" -maxdepth 1 -type d -name 'wine-*' | head -1)
for p in "$P"/*.patch; do patch -d "$src" -p1 < "$p"; done
mkdir build; cd build
nix shell nixpkgs#gcc nixpkgs#flex nixpkgs#bison nixpkgs#pkg-config nixpkgs#gnumake nixpkgs#perl -c bash -c "
  '$src/configure' --enable-win64 --without-mingw --without-x --without-freetype --without-gnutls \
     --without-wayland --without-vulkan --without-opengl --disable-tests > configure.log 2>&1
  make -j\${JOBS:-4} server/wineserver > make.log 2>&1"
wine=$(nix eval --raw "$attr.outPath"); nix build --no-link "$attr"
mkdir -p "$out/bin"
install -m755 server/wineserver "$out/bin/wineserver"; strip "$out/bin/wineserver" || true
ln -sfn "$wine/share" "$out/share"   # nls files are found via ../share/wine/nls
echo "built $out/bin/wineserver for $wine"
