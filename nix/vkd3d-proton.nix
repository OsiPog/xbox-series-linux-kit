# Cross-builds vkd3d-proton (Windows DLLs) from a local checkout with mingw-w64.
#   NIX_PATH=nixpkgs=$(nix eval --raw nixpkgs#path) nix build -f nix/vkd3d-proton.nix --arg src ./vkd3d-proton -o vkd3d-result
#   -> vkd3d-result/bin/{d3d12,d3d12core}.dll
{ src, pkgs ? import <nixpkgs> {} }:
pkgs.pkgsCross.mingwW64.vkd3d-proton.overrideAttrs (o: {
  version = "local";
  src = builtins.path { path = src; name = "vkd3d-proton-src"; filter = p: t: baseNameOf p != ".git"; };
  postPatch = ''
    substituteInPlace meson.build \
      --replace-fail "vkd3d_build = vcs_tag(" "vkd3d_build = vcs_tag( fallback : 'local'," \
      --replace-fail "vkd3d_version = vcs_tag(" "vkd3d_version = vcs_tag( fallback : 'local',"
  '';
  nativeBuildInputs = with pkgs; [ glslang meson ninja wine64 python3 ];
  buildInputs = [ pkgs.pkgsCross.mingwW64.windows.pthreads ];
  meta = { platforms = pkgs.lib.platforms.all; };
  passthru = {};
  mesonFlags = (o.mesonFlags or []) ++ [ "-Db_ndebug=true" "-Denable_tests=false" ];
})
