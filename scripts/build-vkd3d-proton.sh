#!/usr/bin/env bash
# Clones vkd3d-proton at the tested commit, applies patches/vkd3d-proton, builds the Windows DLLs with nix.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd); W=${WORK:-$ROOT/work}; mkdir -p "$W"
REV=ec20719452e916baa2b9e69f33f18de4561a8313
[ -d "$W/vkd3d-proton" ] || git clone --recurse-submodules https://github.com/HansKristian-Work/vkd3d-proton.git "$W/vkd3d-proton"
cd "$W/vkd3d-proton"; git checkout -q "$REV"; git submodule update --init --recursive -q
git am -q "$ROOT"/patches/vkd3d-proton/*.patch
NIX_PATH=nixpkgs=$(nix eval --raw nixpkgs#path) nix build -f "$ROOT/nix/vkd3d-proton.nix" --arg src "$W/vkd3d-proton" -o "$W/vkd3d-result"
echo "DLLs: $W/vkd3d-result/bin/"
