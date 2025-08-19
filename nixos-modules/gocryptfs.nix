{
  config,
  pkgs,
  lib,
  utils,
  ...
}:
let
  cfg = config.dev.johnrinehart.gocryptfs;

  gocryptfs = lib.types.submodule {
    options = {
      cipherMount = lib.mkOption {
        description = "mount point of encrypted data";
        default = "";
        type = lib.types.nonEmptyStr;
      };
      plaintextMount = lib.mkOption {
        description = "mount point of decrypted data";
        default = "";
        type = lib.types.nonEmptyStr;
      };
      passwordFile = lib.mkOption {
        description = "file containing password used to decrypt the cipherMount";
      };
    };
  };
in
{
  options.dev.johnrinehart.gocryptfs = {
    enable = lib.mkEnableOption "gocryptfs mounts";

    mounts = lib.mkOption { type = lib.types.listOf gocryptfs; };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.gocryptfs ];
    fileSystems = builtins.listToAttrs (
      builtins.map (x: {
        name = lib.last (lib.splitString "/" x.plaintextMount);
        value = {
          device = x.cipherMount;
          mountPoint = x.plaintextMount;
          fsType = "fuse.${builtins.unsafeDiscardStringContext pkgs.gocryptfs}/bin/gocryptfs";
          #noCheck = true;
          depends = x.cipherMount;
          # cf. https://unix.stackexchange.com/a/349278
          options = [
            "x-systemd.automount"
            "allow_other"
            "passfile=${x.passwordFile}"
          ];
          #"x-systemd.after=${utils.escapeSystemdPath x.cipherMount}.mount"
        };
      }) cfg.mounts
    );
  };
}
