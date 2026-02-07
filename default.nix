{ lib
, stdenv
, zig_0_15
, callPackage
}:

stdenv.mkDerivation {
  pname = "vanish";
  version = "0.1.0";

  src = lib.cleanSource ./.;

  nativeBuildInputs = [ zig_0_15 ];

  dontConfigure = true;
  dontInstall = true;

  buildPhase = ''
    runHook preBuild

    export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-cache"
    export ZIG_LOCAL_CACHE_DIR="$TMPDIR/zig-cache"

    zig build \
      --release=safe \
      --prefix $out \
      -Doptimize=ReleaseSafe

    runHook postBuild
  '';

  meta = with lib; {
    description = "Lightweight terminal session multiplexer using libghostty";
    homepage = "https://github.com/psyc/vanish";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "vanish";
  };
}
