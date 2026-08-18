{
  pkgs,
  buildInputs,
  nativeBuildInputs,
}:
pkgs.mkShell rec {
  inherit buildInputs nativeBuildInputs;

  shellHook = ''
    PS1="(dev) $PS1"
    export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath nativeBuildInputs}"
  '';
}
