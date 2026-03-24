{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dev.johnrinehart.rock5c.media;
  managementCfg = cfg.management;

  defaultSession = lib.toLower (lib.attrByPath [ "services" "displayManager" "defaultSession" ] "" config);
  desktopVariant = lib.toLower (lib.attrByPath [ "dev" "johnrinehart" "desktop" "variant" ] "" config);

  waylandSession =
    lib.attrByPath [ "programs" "niri" "enable" ] false config
    || lib.attrByPath [ "programs" "hyprland" "enable" ] false config
    || lib.attrByPath [ "programs" "sway" "enable" ] false config
    || lib.hasInfix "wayland" defaultSession
    || lib.hasInfix "niri" defaultSession
    || lib.hasInfix "hypr" defaultSession
    || lib.hasInfix "sway" defaultSession
    || lib.hasInfix "wayland" desktopVariant
    || lib.hasInfix "niri" desktopVariant
    || lib.hasInfix "hypr" desktopVariant
    || lib.hasInfix "sway" desktopVariant;

  x11Session = lib.attrByPath [ "services" "xserver" "enable" ] false config && !waylandSession;

  autoKodiVariant =
    if waylandSession then
      "wayland"
    else if x11Session then
      "x11"
    else
      "gbm";

  effectiveKodiVariant = if cfg.kodi.variant == "auto" then autoKodiVariant else cfg.kodi.variant;
  selectedKodiAttr = "kodi_22-${effectiveKodiVariant}-v4l2request";
  selectedKodiPkg = builtins.getAttr selectedKodiAttr pkgs;
  kodiAutostartLauncher = pkgs.writeShellScriptBin "rock5c-kodi-autostart" ''
    set -eu

    ${lib.optionalString (effectiveKodiVariant == "wayland") ''
      unset DISPLAY
      if [ -z "''${XDG_RUNTIME_DIR:-}" ]; then
        export XDG_RUNTIME_DIR="/run/user/$(id -u)"
      fi
    ''}

    exec ${lib.getExe selectedKodiPkg}
  '';

  ffmpegWrapper = pkgs.writeShellApplication {
    name = "rock5c-ffmpeg-v4l2request";
    runtimeInputs = [ pkgs.ffmpeg_8-full-v4l2request ];
    text = ''
      exec ffmpeg "$@"
    '';
  };

  ffprobeWrapper = pkgs.writeShellApplication {
    name = "rock5c-ffprobe-v4l2request";
    runtimeInputs = [ pkgs.ffmpeg_8-full-v4l2request ];
    text = ''
      exec ffprobe "$@"
    '';
  };

  ffplayWrapper = pkgs.writeShellApplication {
    name = "rock5c-ffplay-v4l2request";
    runtimeInputs = [ pkgs.ffmpeg_8-full-v4l2request ];
    text = ''
      exec ffplay "$@"
    '';
  };

  h264Test = pkgs.writeShellApplication {
    name = "rock5c-ffmpeg-h264-v4l2request-test";
    runtimeInputs = [ pkgs.ffmpeg_8-full-v4l2request ];
    text = ''
      set -eu

      if [ "$#" -ne 1 ]; then
        echo "usage: rock5c-ffmpeg-h264-v4l2request-test /path/to/h264-file" >&2
        exit 2
      fi

      exec ffmpeg \
        -hide_banner \
        -loglevel verbose \
        -hwaccel v4l2request \
        -hwaccel_output_format drm_prime \
        -i "$1" \
        -an \
        -frames:v 300 \
        -f null -
    '';
  };

  hevcTest = pkgs.writeShellApplication {
    name = "rock5c-ffmpeg-hevc-v4l2request-test";
    runtimeInputs = [ pkgs.ffmpeg_8-full-v4l2request ];
    text = ''
      set -eu

      if [ "$#" -ne 1 ]; then
        echo "usage: rock5c-ffmpeg-hevc-v4l2request-test /path/to/hevc-file" >&2
        exit 2
      fi

      exec ffmpeg \
        -hide_banner \
        -loglevel verbose \
        -hwaccel v4l2request \
        -hwaccel_output_format drm_prime \
        -i "$1" \
        -an \
        -frames:v 300 \
        -f null -
    '';
  };

  torrentRoots = rec {
    downloadsRoot = toString managementCfg.downloadsRoot;
    files = "${downloadsRoot}/files";
    downloading = "${downloadsRoot}/downloading";
    completed = "${downloadsRoot}/completed";
  };

  mediaRoots = rec {
    root = toString managementCfg.mediaRoot;
    movies = "${root}/movies";
    tvShows = "${root}/tv_shows";
  };

  servicesRoot = toString managementCfg.servicesRoot;
  delugeDataDir = "${servicesRoot}/deluge";
  sonarrDataDir = "${servicesRoot}/sonarr";
  radarrDataDir = "${servicesRoot}/radarr";
in
{
  options.dev.johnrinehart.rock5c.media = {
    enable = lib.mkEnableOption "Rock 5C media packages and Kodi session variants";

    ffmpegTools.enable = lib.mkEnableOption "Rock 5C FFmpeg V4L2 request tools" // {
      default = true;
    };

    mpv.enable = lib.mkEnableOption "Rock 5C mpv linked against FFmpeg V4L2 request" // {
      default = true;
    };

    management = {
      enable = lib.mkEnableOption "Rock 5C Sonarr/Radarr/Deluge NAS layout and permissions";

      downloadsRoot = lib.mkOption {
        type = lib.types.path;
        default = "/mnt/nas/torrents";
        description = ''
          Root directory for torrent state on the NAS.
          Deluge should use `${lib.literalExpression "/mnt/nas/torrents/downloading"}` for
          active downloads, `${lib.literalExpression "/mnt/nas/torrents/files"}` for torrent
          metadata, and `${lib.literalExpression "/mnt/nas/torrents/completed"}` for completed
          data that Sonarr/Radarr can hardlink from.
        '';
      };

      mediaRoot = lib.mkOption {
        type = lib.types.path;
        default = "/mnt/nas/media";
        description = "Root directory for the curated media library.";
      };

      servicesRoot = lib.mkOption {
        type = lib.types.path;
        default = "/mnt/nas/.services";
        description = "Root directory for service state stored on the NAS.";
      };

      sonarr.enable = lib.mkEnableOption "Sonarr" // {
        default = true;
      };

      radarr.enable = lib.mkEnableOption "Radarr" // {
        default = true;
      };
    };

    kodi = {
      enable = lib.mkEnableOption "Rock 5C Kodi 22 V4L2 request package" // {
        default = true;
      };

      autostart.enable = lib.mkEnableOption "autostart Kodi after the compositor/session comes up";

      disable_cec_standby_on_poweroff = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Apply a Rock 5C-specific Kodi patch that suppresses HDMI-CEC standby and
          inactive-source commands when Kodi exits.

          This may fix TVs that power off when Kodi is closed while still keeping
          basic CEC remote input working.
        '';
      };

      variant = lib.mkOption {
        type = lib.types.enum [
          "auto"
          "wayland"
          "x11"
          "gbm"
        ];
        default = "auto";
        description = ''
          Which Kodi frontend variant to expose as `pkgs.kodi_22` and install by default.
          `auto` prefers Wayland when a Wayland compositor is detected, X11 when Xorg is
          enabled without a Wayland compositor, and GBM otherwise.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = [
      (final: prev:
        let
          kodiPatches =
            [
            ../../../patches/kodi/0001-rock5c-force-drm-prime-on-gbm.patch
            ]
            ++ lib.optionals cfg.kodi.disable_cec_standby_on_poweroff [
              # This suppresses Kodi's CEC standby/inactive-source power-off path.
              # Enable it if your TV powers off when Kodi exits.
              ../../../patches/kodi/0002-rock5c-dont-send-cec-standby-on-exit.patch
            ];

          mkKodi22Variant =
            baseName:
            let
              basePkg = (builtins.getAttr baseName prev).override {
                ffmpeg = final.ffmpeg_8-full-v4l2request;
              };
            in
            basePkg.overrideAttrs (old: {
                version = "22.0a2";
                kodiReleaseName = "Piers";

                src = prev.fetchFromGitHub {
                  owner = "xbmc";
                  repo = "xbmc";
                  rev = "22.0a2-Piers";
                  hash = "sha256-6+hpADxmZH2jc4mgzbnX0UO4LK1AY9WPY36HQ6rmK2I=";
                };

                patches = (old.patches or [ ]) ++ kodiPatches;

                buildInputs = (old.buildInputs or [ ]) ++ [
                  final.libsysprof-capture
                  final.pcre2
                  final.exiv2
                  final.nlohmann_json
                ];

                cmakeFlags =
                  lib.filter (flag: !(lib.hasPrefix "-DAPP_RENDER_SYSTEM=" flag)) (old.cmakeFlags or [ ])
                  ++ [
                  # Build Kodi against the GLES render backend on Rock 5C.
                  # On this stack, the working Wayland DRM PRIME decode/render path
                  # is registered through Kodi's GLES winsystem, while the GL path
                  # has been observed to fall back to software decode.
                  "-DAPP_RENDER_SYSTEM=gles"
                  "-DENABLE_INTERNAL_CROSSGUID=OFF"
                  "-DENABLE_INTERNAL_EXIV2=OFF"
                  "-DENABLE_INTERNAL_NLOHMANNJSON=OFF"
                  "-DCROSSGUID_INCLUDE_DIR=${final.libcrossguid}/include"
                  "-DCROSSGUID_LIBRARY=${final.libcrossguid}/lib/libcrossguid.a"
                  "-DCROSSGUID_LIBRARY_RELEASE=${final.libcrossguid}/lib/libcrossguid.a"
                  "-DEXIV2_INCLUDE_DIR=${final.exiv2}/include"
                  "-DEXIV2_LIBRARY=${final.exiv2}/lib/libexiv2.so"
                  "-DEXIV2_LIBRARY_RELEASE=${final.exiv2}/lib/libexiv2.so"
                ];

                passthru = (old.passthru or { }) // {
                  ffmpeg = final.ffmpeg_8-full-v4l2request;
                  frontend = baseName;
                };
              });

          kodi22Wayland = mkKodi22Variant "kodi-wayland";
          kodi22X11 = mkKodi22Variant "kodi";
          kodi22Gbm = mkKodi22Variant "kodi-gbm";
        in
        {
          "kodi_22-wayland-v4l2request" = kodi22Wayland;
          "kodi_22-x11-v4l2request" = kodi22X11;
          "kodi_22-gbm-v4l2request" = kodi22Gbm;

          kodi_22_wayland_v4l2request = kodi22Wayland;
          kodi_22_x11_v4l2request = kodi22X11;
          kodi_22_gbm_v4l2request = kodi22Gbm;

          "kodi_22-v4l2request" = builtins.getAttr selectedKodiAttr final;
          kodi_22_v4l2request = builtins.getAttr selectedKodiAttr final;
          kodi_22 = builtins.getAttr selectedKodiAttr final;
        })
    ];

    environment.systemPackages =
      lib.optionals cfg.ffmpegTools.enable [
        pkgs.ffmpeg_8-full-v4l2request
        ffmpegWrapper
        ffprobeWrapper
        ffplayWrapper
        h264Test
        hevcTest
      ]
      ++ lib.optionals cfg.mpv.enable [ pkgs.mpv_v4l2request ]
      ++ lib.optionals cfg.kodi.enable [ selectedKodiPkg ]
      ++ lib.optionals (cfg.kodi.enable && cfg.kodi.autostart.enable) [ kodiAutostartLauncher ];

    environment.shellAliases = lib.mkIf cfg.ffmpegTools.enable {
      "ffmpeg-v4l2request" = "${ffmpegWrapper}/bin/rock5c-ffmpeg-v4l2request";
      "ffprobe-v4l2request" = "${ffprobeWrapper}/bin/rock5c-ffprobe-v4l2request";
      "ffplay-v4l2request" = "${ffplayWrapper}/bin/rock5c-ffplay-v4l2request";
    };

    environment.etc = lib.mkIf (cfg.kodi.enable && cfg.kodi.autostart.enable) {
      "xdg/autostart/rock5c-kodi.desktop".text = ''
        [Desktop Entry]
        Type=Application
        Name=Kodi
        Comment=Autostart Kodi after the desktop session initializes
        Exec=${kodiAutostartLauncher}/bin/rock5c-kodi-autostart
        Terminal=false
        X-GNOME-Autostart-enabled=true
      '';
    };

    systemd.tmpfiles.rules = lib.optionals managementCfg.enable [
      "d '${servicesRoot}' 0775 john media - -"
      "d '${torrentRoots.downloadsRoot}' 2775 deluge media - -"
      "d '${torrentRoots.files}' 2775 deluge media - -"
      "d '${torrentRoots.downloading}' 2775 deluge media - -"
      "d '${torrentRoots.completed}' 2775 deluge media - -"
      "z '${torrentRoots.downloadsRoot}' 2775 deluge media - -"
      "z '${torrentRoots.files}' 2775 deluge media - -"
      "z '${torrentRoots.downloading}' 2775 deluge media - -"
      "z '${torrentRoots.completed}' 2775 deluge media - -"
      "d '${mediaRoots.root}' 2775 john media - -"
      "d '${mediaRoots.movies}' 2775 john media - -"
      "d '${mediaRoots.tvShows}' 2775 john media - -"
      "z '${mediaRoots.root}' 2775 john media - -"
      "z '${mediaRoots.movies}' 2775 john media - -"
      "z '${mediaRoots.tvShows}' 2775 john media - -"
    ];

    users.groups = lib.mkIf managementCfg.enable {
      media = { };
    };

    users.users.john.extraGroups = lib.mkIf managementCfg.enable [ "media" ];
    users.users.deluge.extraGroups = lib.mkIf (managementCfg.enable && config.services.deluge.enable) [ "media" ];
    users.users.sonarr.extraGroups = lib.mkIf (managementCfg.enable && managementCfg.sonarr.enable) [ "media" ];
    users.users.radarr.extraGroups = lib.mkIf (managementCfg.enable && managementCfg.radarr.enable) [ "media" ];
    users.users.jellyfin.extraGroups = lib.mkIf (managementCfg.enable && config.services.jellyfin.enable) [ "media" ];

    services.deluge = lib.mkIf managementCfg.enable {
      enable = lib.mkDefault true;
      web = {
        enable = lib.mkDefault true;
        openFirewall = lib.mkDefault true;
      };
      openFilesLimit = lib.mkDefault 1048576;
      dataDir = lib.mkDefault delugeDataDir;
      group = lib.mkDefault "media";
    };

    services.sonarr = lib.mkIf (managementCfg.enable && managementCfg.sonarr.enable) {
      enable = true;
      openFirewall = lib.mkDefault true;
      dataDir = sonarrDataDir;
      group = "media";
    };

    services.radarr = lib.mkIf (managementCfg.enable && managementCfg.radarr.enable) {
      enable = true;
      openFirewall = lib.mkDefault true;
      dataDir = radarrDataDir;
      group = "media";
    };

    systemd.services.deluged.unitConfig.RequiresMountsFor = lib.mkIf (managementCfg.enable && config.services.deluge.enable) [
      delugeDataDir
      torrentRoots.downloadsRoot
    ];
    systemd.services.deluged.serviceConfig.UMask = lib.mkIf (managementCfg.enable && config.services.deluge.enable) "0002";
    systemd.services.delugeweb.unitConfig.RequiresMountsFor = lib.mkIf (
      managementCfg.enable
      && config.services.deluge.enable
      && config.services.deluge.web.enable
    ) [
      delugeDataDir
      torrentRoots.downloadsRoot
    ];
    systemd.services.sonarr = lib.mkIf (managementCfg.enable && managementCfg.sonarr.enable) {
      unitConfig.RequiresMountsFor = [
        sonarrDataDir
        torrentRoots.completed
        mediaRoots.tvShows
      ];
      serviceConfig.UMask = "0002";
    };
    systemd.services.radarr = lib.mkIf (managementCfg.enable && managementCfg.radarr.enable) {
      unitConfig.RequiresMountsFor = [
        radarrDataDir
        torrentRoots.completed
        mediaRoots.movies
      ];
      serviceConfig.UMask = "0002";
    };
  };
}
