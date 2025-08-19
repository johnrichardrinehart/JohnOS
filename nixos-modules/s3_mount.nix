{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.dev.johnrinehart.s3_mount;

  s3mount = lib.types.submodule {
    options = rec {
      mountPoint = lib.mkOption {
        description = "fs mountpoint";
        type = lib.types.nullOr lib.types.nonEmptyStr;
        default = null;
      };
      url = lib.mkOption {
        description = "url";
        default = "";
        type = lib.types.nonEmptyStr;
      };
      bucketName = lib.mkOption {
        description = "bucket name";
        default = "";
        type = lib.types.nonEmptyStr;
      };
      # Should be in the form <accessKeyId:secretAccessKey>
      passwordFile = lib.mkOption {
        description = "password file";
        default = "/";
        type = lib.types.path;
      };
    };
  };
in
{
  options.dev.johnrinehart.s3_mount = {
    enable = lib.mkEnableOption "S3 fuse mounts";

    mounts = lib.mkOption { type = lib.types.listOf s3mount; };
  };

  config = lib.mkIf cfg.enable {
    # because we need to use unsafeDiscardStringContext (because of an
    # eval-failure caused when trying to interpolate the /nix/store path in the
    # fstab "options") we need to inject it into the system's $PATH.
    environment.systemPackages = [ pkgs.s3fs ];
    fileSystems = builtins.listToAttrs (
      builtins.map (x: {
        name = x.bucketName;
        value = {
          device = x.bucketName;
          mountPoint = if x.mountPoint == null then "/mnt/${x.bucketName}" else x.mountPoint;
          fsType = "fuse.${builtins.unsafeDiscardStringContext pkgs.s3fs}/bin/s3fs";
          #noCheck = true;
          # cf. https://unix.stackexchange.com/a/349278
          # "_netdev" "x-systemd.after=network-online.target"
          options = [
            "_netdev"
            "x-systemd.automount"
            "allow_other"
            "use_path_request_style"
            "url=${x.url}"
            "passwd_file=${x.passwordFile}"
            "connect_timeout=30"
            "retries=90"
            "dbglevel=debug"
            "curldbg=body"
          ];
        };
      }) cfg.mounts
    );
  };
}
