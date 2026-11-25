# xbox-series-linux-kit

Scripts and patches to run an **Xbox Series title from your own legitimate console dump** on a Linux PC,
using [VIctory](https://github.com/Marvisak/VIctory) (an Xbox Series → Windows/D3D12 title runner) under Wine,
with a patched [vkd3d-proton](https://github.com/HansKristian-Work/vkd3d-proton) and DXVK's `dxgi.dll`.

No game data and no files from any dump are included or downloaded. You need your own dump.

> **Status: work in progress.** Boot, menus, the intro video and story loading work, and the 3D world
> renders lit. It is far from real time (about 1 frame per second) and characters still show broken
> geometry. See [Known issues](#known-issues).

## Requirements

- Linux with an AMD GPU and Mesa RADV 26.3 or newer (tested: RDNA4, Mesa 26.3.0/26.3.1)
- Wine staging 11.21 from nixpkgs (`wineWow64Packages.stagingFull`) — the patched wineserver is built for exactly this Wine
- [Nix](https://nixos.org) (used to cross-build everything; no system packages are changed)
- Resizable BAR enabled in the BIOS is strongly recommended (without it vkd3d-proton falls back to a slow small-BAR path)

## Build

```sh
scripts/build-vkd3d-proton.sh     # -> work/vkd3d-result/bin/{d3d12,d3d12core}.dll
scripts/build-victory.sh          # -> work/VIctory/target/x86_64-pc-windows-msvc/diag/victory.exe
scripts/build-wineserver.sh       # -> work/wineserver/bin/wineserver (REQUIRED, ~2 min; run.sh uses it automatically)
```

Put the matching Wine on `PATH` (wineserver and Wine must be the same build):

```sh
export PATH=$(nix build --no-link --print-out-paths nixpkgs#wineWow64Packages.stagingFull)/bin:$PATH
```

## Set up a prefix and run

```sh
export WINEPREFIX=$PWD/work/prefix
scripts/setup-prefix.sh work/vkd3d-result/bin
scripts/run.sh /path/to/your/dump          # the dump folder that contains MicrosoftGame.Config
```

`run.sh` finds the title's executable from `MicrosoftGame.Config`. Useful environment variables:

| Variable | Effect |
|---|---|
| `DATA=dir` | where saves and VIctory's caches go (default `./data`) |
| `KEYS_FILE=file` | every line appended to the file (`Enter`, `Escape`, `W`, ...) is pressed as a pad/keyboard input — lets a script drive menus |
| `VICTORY_KEYS="30:Enter,35:X"` | presses keys at fixed seconds |
| `VICTORY_NO_WATCHDOG=1` | (default) stops the title's stall watchdog from ending slow runs |
| `MESA_SHADER_CACHE_MAX_SIZE` | default here 16G; the title has ~22k shader programs and Mesa's 1 GiB default thrashes |
| `VICTORY_PATCH`, `VICTORY_SKIP_PIPELINES`, `VICTORY_SHADER_LOOP_LIMIT`, `VICTORY_SHADER_SPIN_LIMIT`, `VICTORY_LOOSE_UAV_MB` | tested defaults set in `run.sh` (comments there say why); set one to override it |

## What the patches do

- `patches/vkd3d-proton/`
  - fix a double release of `budget_lock` when every memory type is refused (shows up under Wine as
    `RtlReleaseSRWLockExclusive ... is not owned exclusive`)
  - allow more than 1,000,000 shader-visible view descriptors without ReBAR (the title asks for ~1.25M)
- `patches/wine/`: wineserver keeps each process's mapped views in a red-black tree instead of scanning a
  linked list on every map/unmap/address query. The runner maps tens of thousands of views; stock wineserver
  spends most of its time in those scans and boot/story loading stall for many minutes.
- `patches/victory/linux-int.diff`: fixes on top of upstream VIctory `940d32f` (integration branch at 405b907):
  24-bit depth twins (open upstream PR #1964), shader-translation and GPU fixes, Wine fixes, and run switches
  (`VICTORY_NO_WATCHDOG`, `VICTORY_KEYS_FILE`, `VICTORY_PATCH`); `CONTENTS.txt` lists the commits.

## Known issues

- The patched wineserver is required: with the stock one, boot stalls for 8+ minutes and story loading never finishes.
- About 0.7-1.5 frames per second in the world.
- Characters show spiky broken triangles.
- A first visit translates ~22k shader programs; expect long loads until VIctory's and Mesa's caches are warm.

## Credits

All the heavy lifting is upstream: VIctory, xcl, Xbox2Windows, vkd3d-proton, DXVK, Wine, Mesa.

## License

Each patch is under the license of the project it applies to (VIctory: GPL-3.0; Wine and vkd3d-proton: LGPL-2.1+).
The scripts are MIT-licensed.
