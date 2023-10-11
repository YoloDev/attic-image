{
  perSystem = { lib, pkgs, arch, buildImage, buildLayer, ... }:
    let
      layers = rec {
        busybox = buildLayer {
          deps = [ pkgs.busybox ];
        };

        tini = buildLayer {
          deps = [ pkgs.tini ];

          layers = [ busybox ];
        };

        certs = buildLayer {
          deps = [ pkgs.cacert ];
        };
      };

      mkAtticdImage = name: mode:
        let
          tag = "v${pkgs.attic-server.version}";
          imgMeta = {
            inherit name arch tag;
            inherit (pkgs.attic-server) version;
          };
          img = pkgs.makeOverridable buildImage
            {
              inherit name tag;

              layers = [
                layers.busybox
                layers.tini
                layers.certs
              ];

              config = {
                Entrypoint = [ "${pkgs.tini}/bin/tini" ];
                Cmd = [ "--" "${pkgs.attic-server}/bin/atticd" "--mode" mode ];
                Env = [
                  "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
                ];
              };
            };
        in
        { inherit imgMeta; } // img;

    in
    {
      images = {
        attic-server = mkAtticdImage "attic-server" "api-server";
        attic-gc = mkAtticdImage "attic-gc" "garbage-collector-once";
        attic-db-migrations = mkAtticdImage "attic-db-migrations" "db-migrations";
        attic-check-config = mkAtticdImage "attic-check-config" "check-config";
      };
    };
}
