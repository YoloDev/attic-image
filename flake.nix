{
  description = "OCI image for attic";

  # the nixConfig here only affects the flake itself, not the system configuration!
  nixConfig = {
    experimental-features = [ "nix-command" "flakes" ];

    substituters = [
      "https://cache.nixos.org"
    ];

    # nix community's cache server
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://staging.attic.rs/attic-ci"
    ];
    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "attic-ci:U5Sey4mUxwBXM3iFapmP0/ogODXywKLRNgRPQpEXxbo="
    ];
  };

  inputs = {
    # Pin our primary nixpkgs repository. This is the main nixpkgs repository
    # we'll use for our configurations. Be very careful changing this because
    # it'll impact your entire system.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";

    attic = {
      url = "github:zhaofengli/attic";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
      inputs.nixpkgs-stable.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ attic, nixpkgs, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } ({ lib, flake-parts-lib, ... }: {
      imports = [
        (flake-parts-lib.mkTransposedPerSystemModule {
          name = "foo";
          file = ./flake.nix;
          option = lib.mkOption {
            type = lib.types.lazyAttrsOf lib.types.raw;
            default = { };
          };
        })
      ];

      systems = [
        "x86_64-linux"
        # "aarch64-linux"
      ];

      perSystem = { system, ... }:
        let
          pkgs = import inputs.nixpkgs {
            inherit system;
            overlays = [ attic.overlays.default ];
          };

          mkSystem = arch: native:
            let
              pkgs = (import inputs.nixpkgs {
                inherit system;
                overlays = [ attic.overlays.default ];
                # crossSystem = { config = "${arch}-unknown-linux-gnu"; };
              }).pkgs;
            in
            {
              inherit arch pkgs;
              system = native;
            };

          crossSystems =
            [
              (mkSystem "x86_64" "x86_64-linux")
              # (mkSystem "aarch64" "aarch64-linux")
            ];

          imagesPerArch = builtins.map
            (sys:
              let
                imagesSet = import ./images.nix {
                  inherit (sys) arch pkgs;
                };
                imagesNames = builtins.attrNames imagesSet;
                images = builtins.map (name: imagesSet.${name}) imagesNames;
              in
              images)
            crossSystems;

          imagesFlat = builtins.concatLists imagesPerArch;
          imagesByName = builtins.groupBy (image: image.imgMeta.name) imagesFlat;
          loadImg = image:
            ''
              IMG=$(podman load -i "${image}" 2>/dev/null | ${pkgs.coreutils}/bin/cut -c 25-)
              echo "Loaded ${image.imgMeta.name} as localhost/$IMG"
              podman push "localhost/$IMG" "docker.io/alxandr/$IMG"
            '';
          loadImgs = images: builtins.concatStringsSep "\n" (builtins.map loadImg images);
          imagesPkgs = lib.mapAttrs
            (name: images: pkgs.writeShellApplication {
              inherit name;
              text = loadImgs images;
            })
            imagesByName;
          allPkgs = {
            all-images = pkgs.writeShellApplication {
              name = "all-images";
              text = loadImgs imagesFlat;
            };
            attic = pkgs.attic;
          };
        in
        {
          packages = imagesPkgs // allPkgs;
        };
    });
}
