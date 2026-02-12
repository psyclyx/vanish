{
  lib,
  stdenv,
  callPackage,
  zig_0_15,
}:
stdenv.mkDerivation {
  pname = "vanish";
  version = "1.0.0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./build.zig
      ./build.zig.zon
      ./completions
      ./doc
      ./src
    ];
  };

  postConfigure = ''
    cp -r ${callPackage ./deps.nix { }} $ZIG_GLOBAL_CACHE_DIR/p
  '';

  nativeBuildInputs = [ zig_0_15 ];

  meta = with lib; {
    description = "Lightweight terminal session multiplexer using libghostty";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "vanish";
  };
}
