{ lib, flake-parts-lib, config, inputs, ... }:
with lib;
let
  targetArchs = {
    "x86_64-linux" = "x86_64";
    "aarch64-linux" = "aarch64";
  };
in
{
  options = {
    perSystem = flake-parts-lib.mkPerSystemOption {
      options.images = mkOption {
        description = "OCI or docker image package";
        type = types.lazyAttrsOf types.package;
        default = { };
      };
    };
  };

  config.perSystem = { system, ... }: {
    _module.args.arch = targetArchs.${system};
  };
}
