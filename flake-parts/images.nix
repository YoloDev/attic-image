{ lib, flake-parts-lib, config, inputs, ... }:
with lib;
let
  inherit (config) systems;

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
        type = types.lazyAttrsOf types.raw;
        default = { };
      };
    };

    allImages = mkOption {
      type = types.unspecified;
      description = "All images, regardless of system.";
      internal = true;
    };
  };

  config = {
    perSystem = { system, pkgs, ... }: {
      _module.args.arch = targetArchs.${system};

      packages =
        let
          images = config.allImages;
          writeMany = name: arches:
            let
              images = lib.attrValues arches;
              lines = lib.concatLines (builtins.map (image: ''ln -s ${image} "$out/${image.imgMeta.arch}.json"'') images);
              image = builtins.toJSON {
                references = builtins.map (image: image.imageRefUnsafe) images;
              };
              env = {
                inherit image;
              };
              cmd =
                ''
                  mkdir -p "$out"
                  echo "$image" >"$out/image.json"

                  ${lines}
                '';
            in
            pkgs.runCommand "${name}" env cmd;
        in
        lib.mapAttrs writeMany images;
    };

    allImages =
      let
        systemize = system:
          let
            arch = targetArchs.${system};
            images = config.allSystems.${system}.images;
          in
          lib.mapAttrsToList
            (name: image: (image.override {
              tag = "${image.imageTag}-${arch}";
            }) // { inherit (image) imgMeta; })
            images;

        allImages = lib.flatten (builtins.map systemize systems);
        byName = lib.groupBy (image: image.imgMeta.name) allImages;
        withArch = lib.mapAttrs
          (name: images: lib.listToAttrs (builtins.map
            (img: {
              name = img.imgMeta.arch;
              value = img;
            })
            images))
          byName;
      in
      withArch;
  };
}
