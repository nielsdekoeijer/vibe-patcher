{
  pkgs,
  nativeBuildInputs,
}:
let
in
pkgs.stdenv.mkDerivation {
  inherit nativeBuildInputs;

  pname = "vibe-patcher";

  version = "0.1.0";

  src = ./.;

  preBuild = ''
    export ZIG_GLOBAL_CACHE_DIR=$TMPDIR
  '';

  installPhase = ''
    runHook preInstall

    zig build -Doptimize=ReleaseSafe --prefix $out install

    runHook postInstall
  '';

  outputs = [ "out" ];
}
