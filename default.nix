let
  sources = import ./npins;
  pkgs = import sources.nixpkgs-unstable {};
in
  pkgs.callPackage ./package.nix {}
