{
  description = "vibe-patcher";

  inputs = {
    nixpkgs = {
      url = "github:nixos/nixpkgs?ref=nixos-unstable";
    };

    utils = {
      url = "github:numtide/flake-utils";
    };

    zig-flake = {
      url = "github:mitchellh/zig-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zls-flake = {
      url = "github:zigtools/zls?ref=0.16.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    msdf-atlas-gen = {
      url = "git+https://github.com/Chlumsky/msdf-atlas-gen?submodules=1";
      flake = false;
    };

  };

  outputs =
    {
      self,
      nixpkgs,
      utils,
      zig-flake,
      zls-flake,
      msdf-atlas-gen,
    }:
    utils.lib.eachDefaultSystem (
      system:
      let
        # packages for the given system
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            (final: prev: {
              zig = zig-flake.packages.${system}."0.16.0";

              zls = zls-flake.packages.${system}.default.overrideAttrs (old: {
                nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ final.zig ];
              });

              msdf-atlas-gen = prev.stdenv.mkDerivation {
                pname = "msdf-atlas-gen";
                version = "git";

                src = msdf-atlas-gen;

                nativeBuildInputs = [ prev.cmake ];
                buildInputs = [
                  prev.freetype
                  prev.libpng
                ];

                cmakeFlags = [
                  "-DMSDF_ATLAS_USE_VCPKG=OFF"
                  "-DMSDF_ATLAS_USE_SKIA=OFF"
                ];

                installPhase = ''
                  runHook preInstall
                  mkdir -p $out/bin
                  cp bin/msdf-atlas-gen $out/bin/
                  runHook postInstall
                '';
              };

            })
          ];
        };

        buildInputs = [
          pkgs.zls
        ];

        nativeBuildInputs = [
          pkgs.zig
          pkgs.alsa-lib
          pkgs.libdecor
          pkgs.libusb1
          pkgs.libxkbcommon
          pkgs.vulkan-loader
          pkgs.wayland
          pkgs.libx11
          pkgs.libxext
          pkgs.libxi
          pkgs.udev
          pkgs.vulkan-validation-layers
          pkgs.shaderc
          pkgs.msdf-atlas-gen
        ];
      in
      {

        # on `nix build`
        packages.default = pkgs.callPackage ./default.nix {
          inherit pkgs;
          inherit nativeBuildInputs;
        };

        # on `nix develop`
        devShells.default = pkgs.callPackage ./shell.nix {
          inherit pkgs;
          inherit buildInputs;
          inherit nativeBuildInputs;
        };
      }
    );
}
