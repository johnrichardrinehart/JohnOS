{ config, lib, ... }:
let
  servicesRoot = "/mnt/nas/.services";
  torrentRoot = "/mnt/nas/torrents";
  torrentFiles = "${torrentRoot}/files";
  torrentDownloading = "${torrentRoot}/downloading";
  torrentCompleted = "${torrentRoot}/completed";
  mediaRoot = "/mnt/nas/media";
  moviesRoot = "${mediaRoot}/movies";
  tvRoot = "${mediaRoot}/tv_shows";
in
{
  systemd.tmpfiles.rules = [
    "d '${servicesRoot}' 0775 john media - -"
    "d '${torrentRoot}' 2775 deluge media - -"
    "d '${torrentFiles}' 2775 deluge media - -"
    "d '${torrentDownloading}' 2775 deluge media - -"
    "d '${torrentCompleted}' 2775 deluge media - -"
    "z '${torrentRoot}' 2775 deluge media - -"
    "z '${torrentFiles}' 2775 deluge media - -"
    "z '${torrentDownloading}' 2775 deluge media - -"
    "z '${torrentCompleted}' 2775 deluge media - -"
    "d '${mediaRoot}' 2775 john media - -"
    "d '${moviesRoot}' 2775 john media - -"
    "d '${tvRoot}' 2775 john media - -"
    "z '${mediaRoot}' 2775 john media - -"
    "z '${moviesRoot}' 2775 john media - -"
    "z '${tvRoot}' 2775 john media - -"
  ];

  users.groups.media = { };
  users.users.john.extraGroups = [ "media" ];
  users.users.deluge.extraGroups = [ "media" ];
  users.users.sonarr.extraGroups = [ "media" ];
  users.users.radarr.extraGroups = [ "media" ];
  users.users.jellyfin.extraGroups = lib.mkIf config.services.jellyfin.enable [ "media" ];

  services.deluge = {
    enable = lib.mkDefault true;
    web = {
      enable = lib.mkDefault true;
      openFirewall = lib.mkDefault true;
    };
    openFilesLimit = lib.mkDefault 1048576;
    dataDir = lib.mkDefault "${servicesRoot}/deluge";
    group = lib.mkDefault "media";
  };

  services.sonarr = {
    enable = true;
    openFirewall = lib.mkDefault true;
    dataDir = "${servicesRoot}/sonarr";
    group = "media";
  };

  services.radarr = {
    enable = true;
    openFirewall = lib.mkDefault true;
    dataDir = "${servicesRoot}/radarr";
    group = "media";
  };

  systemd.services.deluged.unitConfig.RequiresMountsFor = [
    "${servicesRoot}/deluge"
    torrentRoot
  ];
  systemd.services.deluged.serviceConfig.UMask = "0002";
  systemd.services.delugeweb.unitConfig.RequiresMountsFor = [
    "${servicesRoot}/deluge"
    torrentRoot
  ];
  systemd.services.sonarr = {
    unitConfig.RequiresMountsFor = [
      "${servicesRoot}/sonarr"
      torrentCompleted
      tvRoot
    ];
    serviceConfig.UMask = "0002";
  };
  systemd.services.radarr = {
    unitConfig.RequiresMountsFor = [
      "${servicesRoot}/radarr"
      torrentCompleted
      moviesRoot
    ];
    serviceConfig.UMask = "0002";
  };
}
