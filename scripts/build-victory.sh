#!/usr/bin/env bash
# Clones upstream VIctory at the tested base, applies patches/victory/linux-int.diff and cross-builds
# the Windows diagnostics build (VICTORY_NO_WATCHDOG, VICTORY_KEYS_FILE, captures) with cargo-xwin.
# Needs: nix (flakes). Output: $WORK/VIctory/target/x86_64-pc-windows-msvc/diag/victory.exe
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd); W=${WORK:-$ROOT/work}; mkdir -p "$W"
BASE=ffe310eb
[ -d "$W/VIctory" ] || git clone https://github.com/Marvisak/VIctory.git "$W/VIctory"
cd "$W/VIctory"; git checkout -q -B linux "$BASE"; git apply --index "$ROOT/patches/victory/linux-int.diff"
git -c user.name=kit -c user.email=kit@localhost commit -qm "linux kit patches" || true
export RUSTUP_HOME=$W/.rustup CARGO_HOME=$W/.cargo XWIN_CACHE_DIR=$W/.xwin
nix shell nixpkgs#rustup nixpkgs#cargo-xwin nixpkgs#gcc nixpkgs#llvmPackages_20.clang-unwrapped \
  nixpkgs#llvmPackages_20.lld nixpkgs#llvmPackages_20.llvm -c bash -c '
  export PATH=$CARGO_HOME/bin:$PATH
  cargo xwin build -j${JOBS:-8} --profile diag -p victory --features diagnostics --target x86_64-pc-windows-msvc'
echo "built: $W/VIctory/target/x86_64-pc-windows-msvc/diag/victory.exe"
