let
  sources = import ./npins;
  zig-overlay = (import sources.flake-compat { src = sources.zig-overlay; }).outputs;
  pkgs = import sources.nixpkgs-unstable {
    overlays = [ zig-overlay.overlays.default ];
  };
  zig = pkgs.zigpkgs."0.15.2";
in
pkgs.mkShell {
  packages = [
    zig
    pkgs.zls
    pkgs.gdb
  ];

  shellHook = ''
    export ZIG_LOCAL_CACHE_DIR="$PWD/.zig-cache"
    export ZIG_GLOBAL_CACHE_DIR="$PWD/.zig-cache"
  '';
}
