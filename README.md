# xbox-series-linux-kit

Scripts and patches to run an **Xbox Series title from your own legitimate console dump** on a Linux PC,
using [VIctory](https://github.com/Marvisak/VIctory) (an Xbox Series → Windows/D3D12 title runner) under Wine,
with a patched [vkd3d-proton](https://github.com/HansKristian-Work/vkd3d-proton) and DXVK's `dxgi.dll`.

No game data and no files from any dump are included or downloaded. You need your own dump.

> **Status: work in progress.** Boot, menus and the intro video render. The 3D world still renders
> incompletely and slowly. See [Known issues](#known-issues).

## Requirements

- Linux with an AMD GPU and Mesa RADV 26.3 or newer (tested: RDNA4, Mesa 26.3.0/26.3.1)
- Wine 11.21+ (staging, wow64 is fine) or Proton Experimental
- [Nix](https://nixos.org) (used to cross-build everything; no system packages are changed)
- Resizable BAR enabled in the BIOS is strongly recommended (without it vkd3d-proton falls back to a slow small-BAR path)

## Build

```sh
scripts/build-vkd3d-proton.sh     # -> work/vkd3d-result/bin/{d3d12,d3d12core}.dll
scripts/build-victory.sh          # -> work/VIctory/target/x86_64-pc-windows-msvc/diag/victory.exe
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

## What the patches do

- `patches/vkd3d-proton/`
  - fix a double release of `budget_lock` when every memory type is refused (shows up under Wine as
    `RtlReleaseSRWLockExclusive ... is not owned exclusive`)
  - allow more than 1,000,000 shader-visible view descriptors without ReBAR (the title asks for ~1.25M)
- `patches/victory/linux-int.diff`: Wine/Proton fixes and shader-translation fixes on top of upstream VIctory
  `ffe310e`, mostly from open upstream pull requests; `CONTENTS.txt` lists the commits.

## Known issues

- Under Wine, wineserver can saturate on the very large number of memory views the runner creates,
  stalling boot and the world for minutes (fix in progress).
- Several thousand of the title's shader programs do not translate yet; the world is dark/incomplete.
- World frame times are far from real time.

## Credits

All the heavy lifting is upstream: VIctory, xcl, Xbox2Windows, vkd3d-proton, DXVK, Wine, Mesa.
