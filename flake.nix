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
  };

  outputs =
    {
      self,
      nixpkgs,
      utils,
      zig-flake,
      zls-flake,
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
