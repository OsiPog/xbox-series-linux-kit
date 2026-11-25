#!/usr/bin/env bash
# Creates a Wine prefix with patched vkd3d-proton (d3d12/d3d12core) and DXVK's dxgi.
# Needs: wine, curl, tar.
# usage: WINEPREFIX=/path/prefix scripts/setup-prefix.sh <dir-with-d3d12.dll+d3d12core.dll>
set -euo pipefail
: "${WINEPREFIX:?set WINEPREFIX}"; VK=${1:?vkd3d dll dir}
DXVK_VER=${DXVK_VER:-3.1.1}
wineboot -u >/dev/null 2>&1 || true; wineserver -w
S=$WINEPREFIX/drive_c/windows/system32
cp -f "$VK/d3d12.dll" "$VK/d3d12core.dll" "$S/"
T=$(mktemp -d); curl -fsSL "https://github.com/doitsujin/dxvk/releases/download/v$DXVK_VER/dxvk-$DXVK_VER.tar.gz" | tar xz -C "$T"
cp -f "$T"/dxvk-$DXVK_VER/x64/dxgi.dll "$S/"; rm -rf "$T"
echo "prefix ready: $WINEPREFIX (run with WINEDLLOVERRIDES='d3d12,d3d12core,dxgi=n')"
