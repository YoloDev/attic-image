{ pkgs, arch, ... }:
let
  mkAtticdImage = name: mode:
    let img = pkgs.dockerTools.buildLayeredImage
      {
        name = "${name}";
        tag = "v${pkgs.attic-server.version}-${arch}";

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
        inherit name arch;
        inherit (pkgs.attic-server) version;
      };
    } // img;

in
{
  attic-server = mkAtticdImage "attic-server" "api-server";
  attic-gc = mkAtticdImage "attic-gc" "garbage-collector-once";
  attic-db-migrations = mkAtticdImage "attic-db-migrations" "db-migrations";
  attic-check-config = mkAtticdImage "attic-check-config" "check-config";
}
