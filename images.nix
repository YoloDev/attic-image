{
  perSystem = { lib, pkgs, arch, ... }:
    let
      mkAtticdImage = name: mode:
        let
          tag = "v${pkgs.attic-server.version}";
          img = pkgs.makeOverridable pkgs.dockerTools.streamLayeredImage
            {
              inherit name tag;

              contents = [ pkgs.busybox ];

              config = {
                Entrypoint = [ "${pkgs.tini}/bin/tini" ];
                Cmd = [ "--" "${pkgs.attic-server}/bin/atticd" "--mode" mode ];
                Env = [
                  "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
                ];
              };
            };
        in
        {
          imgMeta = {
            inherit name arch tag;
            inherit (pkgs.attic-server) version;
          };
        } // img;

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
