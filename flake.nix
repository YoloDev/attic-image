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
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";

    flake-parts.url = "github:hercules-ci/flake-parts";

    nix2container = {
      url = "github:nlewo/nix2container";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    attic = {
      url = "github:zhaofengli/attic";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-stable.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ attic, nixpkgs, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } ({ lib, flake-parts-lib, config, ... }:
    {
      imports = [
        ./flake-parts/images.nix
        ./images.nix
        # this is convenient for debugging
        # (flake-parts-lib.mkTransposedPerSystemModule {
        #   name = "foo";
        #   file = ./flake.nix;
        #   option = lib.mkOption {
        #     type = lib.types.lazyAttrsOf lib.types.raw;
        #     default = { };
        #   };
        # })
      ];

      flake._config = config;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];


      perSystem = { system, ... }:
        let
          pkgs = import inputs.nixpkgs {
            inherit system;
            overlays = [ attic.overlays.default ];
          };

          nix2containerPkgs = inputs.nix2container.packages.${system};
          packages = {
            attic = pkgs.attic;
          };

          apps = lib.mapAttrs
            (name: pkg: {
              type = "app";
              program = "${pkg}/bin/${pkg.pname or pkg.name}";
            })
            packages;
        in
        {
          _module.args = {
            inherit pkgs;
            inherit (nix2containerPkgs.nix2container) buildImage buildLayer;
          };

          inherit packages apps;

          devShells.default = pkgs.mkShell {
            buildInputs = with pkgs; [
              attic-client
              git
            ];
          };
        };
    });
}
