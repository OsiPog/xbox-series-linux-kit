#!/usr/bin/env bash
# Creates a Wine prefix with patched vkd3d-proton (d3d12/d3d12core), DXVK's dxgi and Microsoft's DXC.
# Needs: wine, curl, tar, unzip.
# usage: WINEPREFIX=/path/prefix scripts/setup-prefix.sh <dir-with-d3d12.dll+d3d12core.dll>
set -euo pipefail
: "${WINEPREFIX:?set WINEPREFIX}"; VK=${1:?vkd3d dll dir}
DXVK_VER=${DXVK_VER:-3.1.1}
wineboot -u >/dev/null 2>&1 || true; wineserver -w
S=$WINEPREFIX/drive_c/windows/system32
cp -f "$VK/d3d12.dll" "$VK/d3d12core.dll" "$S/"
T=$(mktemp -d); curl -fsSL "https://github.com/doitsujin/dxvk/releases/download/v$DXVK_VER/dxvk-$DXVK_VER.tar.gz" | tar xz -C "$T"
cp -f "$T"/dxvk-$DXVK_VER/x64/dxgi.dll "$S/"; rm -rf "$T"
# Microsoft's DXC (dxcompiler.dll + dxil.dll): VIctory compiles its rectangle-list geometry shaders at runtime
# and normally finds DXC in a Windows SDK, which a Wine prefix doesn't have. run.sh points VICTORY_DXC here.
DXC_TAG=${DXC_TAG:-v1.9.2609} DXC_ZIP=${DXC_ZIP:-dxc_2026_09_29.zip}
D=$WINEPREFIX/drive_c/dxc; mkdir -p "$D"; T=$(mktemp -d)
curl -fsSL -o "$T/dxc.zip" "https://github.com/microsoft/DirectXShaderCompiler/releases/download/$DXC_TAG/$DXC_ZIP"
# (the zip stores Windows paths like bin\x64\dxil.dll, so stream each file out by pattern)
for f in dxcompiler dxil; do unzip -p "$T/dxc.zip" "*x64*$f.dll" > "$D/$f.dll"; done; rm -rf "$T"
echo "prefix ready: $WINEPREFIX (run with WINEDLLOVERRIDES='d3d12,d3d12core,dxgi=n')"
