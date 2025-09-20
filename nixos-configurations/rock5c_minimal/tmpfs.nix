{ lib, ... }:
{

  systemd.mounts = [
    {
      what = "tmpfs";
      where = "/.tmp";
      type = "tmpfs";
      mountConfig.Options = lib.concatStringsSep "," [
        "mode=1777"
        "strictatime"
        "rw"
        "nosuid"
        "nodev"
        "size=20%"
        "huge=within_size"
      ];

      wantedBy = [ "multi-user.target" ];
    }
  ];
}
