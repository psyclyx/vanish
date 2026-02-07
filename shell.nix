{ pkgs ? import <nixpkgs> { } }:

pkgs.mkShell {
  packages = with pkgs; [
    zig_0_15
    zls
    gdb
  ];

  shellHook = ''
    export ZIG_LOCAL_CACHE_DIR="$PWD/.zig-cache"
    export ZIG_GLOBAL_CACHE_DIR="$PWD/.zig-cache"
  '';
}
