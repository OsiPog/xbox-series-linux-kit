#!/usr/bin/env bash
# Runs the title from an Xbox Series dump under Wine with VIctory.
# usage: scripts/run.sh <dump-dir> [victory.exe]
#   env: WINEPREFIX (required), DATA (saves/cache dir, default ./data), KEYS_FILE (append key names to press them),
#        VICTORY_KEYS="30:Enter,35:X" (timed presses),
#        WINESERVER=<patched wineserver> (default: work/wineserver/bin/wineserver when built; started for the prefix)
set -euo pipefail
DUMP=$(realpath "${1:?dump dir}"); EXE=${2:-${WORK:-$(dirname "$0")/../work}/VIctory/target/x86_64-pc-windows-msvc/diag/victory.exe}
: "${WINEPREFIX:?set WINEPREFIX (see setup-prefix.sh)}"
TITLE_EXE=$(grep -o '<Executable Name="[^"]*"' "$DUMP/MicrosoftGame.Config" | head -1 | cut -d'"' -f2)
DATA=$(realpath -m "${DATA:-./data}"); mkdir -p "$DATA/data" "$DATA/cache"
win() { echo "Z:${1//\//\\}"; }
export WINEDLLOVERRIDES="d3d12,d3d12core,dxgi=n" WINEDEBUG=${WINEDEBUG:--all}
export VICTORY_DATA_DIR=$(win "$DATA/data") VICTORY_CACHE_DIR=$(win "$DATA/cache")
export VICTORY_NO_WATCHDOG=${VICTORY_NO_WATCHDOG:-1}
export MESA_SHADER_CACHE_MAX_SIZE=${MESA_SHADER_CACHE_MAX_SIZE:-16G}
# DXC installed by setup-prefix.sh (rectangle-list geometry shaders are compiled with it at runtime)
[ -z "${VICTORY_DXC:-}" ] && [ -f "$WINEPREFIX/drive_c/dxc/dxcompiler.dll" ] && export VICTORY_DXC='C:\dxc\dxcompiler.dll'
# patched wineserver (scripts/build-wineserver.sh) avoids minute-long stalls on the runner's many memory views
WS=${WINESERVER:-${WORK:-$(dirname "$0")/../work}/wineserver/bin/wineserver}
# Wine prefers the wineserver next to its own binaries, so start the patched one for this prefix first;
# wine then reuses the running server.
if [ -x "$WS" ]; then
  WS=$(realpath "$WS"); mkdir -p "$WINEPREFIX"
  wineserver -k 2>/dev/null || true; wineserver -w 2>/dev/null || true
  "$WS" -p20 9>&-
  ok=0; for p in $(pgrep -x -u "$(id -u)" wineserver); do
    [ "$(readlink /proc/$p/exe)" = "$WS" ] && tr '\0' '\n' </proc/$p/environ 2>/dev/null | grep -qx "WINEPREFIX=$WINEPREFIX" && ok=1
  done
  [ $ok = 1 ] && echo "using patched wineserver $WS" >&2 || echo "warning: patched wineserver did not start" >&2
else echo "note: no patched wineserver at $WS - expect long load stalls" >&2; fi
[ -n "${KEYS_FILE:-}" ] && { touch "$KEYS_FILE"; export VICTORY_KEYS_FILE=$(win "$(realpath "$KEYS_FILE")"); }
exec wine "$EXE" run "$(win "$DUMP/$TITLE_EXE")" --execute
