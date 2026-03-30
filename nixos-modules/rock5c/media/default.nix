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
  selectedKodiAttr = "kodi_22-${effectiveKodiVariant}-${cfg.kodi.ffmpegBackend}";
  selectedKodiPkg = builtins.getAttr selectedKodiAttr pkgs;
  kodiAutostartLauncher = pkgs.writeShellScriptBin "rock5c-kodi-autostart" ''
    set -eu

    ${lib.optionalString (effectiveKodiVariant == "wayland") ''
      unset DISPLAY
      if [ -z "''${XDG_RUNTIME_DIR:-}" ]; then
        export XDG_RUNTIME_DIR="/run/user/$(id -u)"
      fi

      wayland_display="''${WAYLAND_DISPLAY:-wayland-1}"
      wayland_socket="$XDG_RUNTIME_DIR/$wayland_display"

      for _ in $(seq 1 40); do
        if [ -S "$wayland_socket" ]; then
          break
        fi
        sleep 0.5
      done

      if [ ! -S "$wayland_socket" ]; then
        echo "rock5c-kodi-autostart: timed out waiting for $wayland_socket" >&2
        exit 1
      fi

      ${lib.optionalString (lib.attrByPath [ "programs" "niri" "enable" ] false config) ''
        for _ in $(seq 1 40); do
          if ${lib.getExe config.programs.niri.package} msg --json outputs 2>/dev/null \
            | ${lib.getExe pkgs.jq} -e 'length > 0 and any(.[]; .current_mode != null)' >/dev/null; then
            break
          fi
          sleep 0.5
        done
      ''}
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
  selectedMpvPkg =
    if cfg.mpv.variant == "rockchip" then
      pkgs.mpv_rockchip
    else
      pkgs.mpv_v4l2request;
in
{
  options.dev.johnrinehart.rock5c.media = {
    enable = lib.mkEnableOption "Rock 5C media packages and Kodi session variants";

    ffmpegTools.enable = lib.mkEnableOption "Rock 5C FFmpeg V4L2 request tools" // {
      default = true;
    };

    mpv.enable = lib.mkEnableOption "Rock 5C mpv package with hardware-decoding-focused FFmpeg" // {
      default = true;
    };

    mpv.variant = lib.mkOption {
      type = lib.types.enum [
        "rockchip"
        "v4l2request"
      ];
      default = "v4l2request";
      description = ''
        Which Rock 5C mpv build to install.
        `rockchip` links mpv against ffmpeg-rockchip for `rkmpp`/RGA support.
        `v4l2request` keeps the local FFmpeg V4L2-request patch stack.
      '';
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

      ffmpegBackend = lib.mkOption {
        type = lib.types.enum [
          "ffmpeg8-rkmpp-v4l2request"
          "ffmpeg8-rkmpp"
          "ffmpeg-rockchip"
        ];
        default = "ffmpeg8-rkmpp-v4l2request";
        description = ''
          Which FFmpeg backend family to use for the Rock 5C Kodi builds.
          `ffmpeg8-rkmpp-v4l2request` builds Kodi against upstream FFmpeg 8 with
          both `rkmpp` and the local V4L2-request patch stack enabled.
          `ffmpeg8-rkmpp` builds Kodi against upstream FFmpeg 8 with `rkmpp` enabled.
          `ffmpeg-rockchip` keeps the downstream `ffmpeg-rockchip` integration work.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = [
      (final: prev:
        let
          commonKodiPatches =
            [
              ../../../patches/kodi/0004-rock5c-add-drm-prime-oes-finishing-path.patch
            ]
            ++ lib.optionals cfg.kodi.disable_cec_standby_on_poweroff [
              # This suppresses Kodi's CEC standby/inactive-source power-off path.
              # Enable it if your TV powers off when Kodi exits.
              ../../../patches/kodi/0002-rock5c-dont-send-cec-standby-on-exit.patch
            ];

          mkKodi22Variant =
            {
              baseName,
              ffmpegPkg,
              backendName,
              hasV4l2Request ? false,
            }:
            let
              basePkg = (builtins.getAttr baseName prev).override {
                ffmpeg = ffmpegPkg;
              };
              variantKodiPatches =
                lib.optionals (baseName == "kodi-gbm") [
                  # This patch intentionally forces DRM PRIME defaults for the
                  # dedicated GBM appliance build. Applying it to Wayland/X11
                  # pulls those frontends onto the same PRIME renderer path.
                  ../../../patches/kodi/0001-rock5c-force-drm-prime-defaults-on-gbm.patch
                ]
                ++ lib.optionals hasV4l2Request [
                  ../../../patches/kodi/0000-rock5c-enable-v4l2request-drm-prime-codec.patch
                ]
                ++ commonKodiPatches;
            in
            basePkg.overrideAttrs (old: {
                version = "22.0a3";
                kodiReleaseName = "Piers";

                src = prev.fetchFromGitHub {
                  owner = "xbmc";
                  repo = "xbmc";
                  rev = "22.0a3-Piers";
                  hash = "sha256-z9MnqMvo2jChmogYOmVz4D42NLgGbmjL19/sRs1AZSI=";
                };

                patches = (old.patches or [ ]) ++ variantKodiPatches;

                buildInputs = (old.buildInputs or [ ]) ++ [
                  final.libcrossguid_with_pc
                  final.libsysprof-capture
                  final.pcre2
                  final.exiv2
                  final.libxslt.out
                  final.nlohmann_json
                ];

                nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
                  final.pkg-config
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
                  "-DEXIV2_INCLUDE_DIR=${final.exiv2}/include"
                  "-DEXIV2_LIBRARY=${final.exiv2}/lib/libexiv2.so"
                  "-DEXIV2_LIBRARY_RELEASE=${final.exiv2}/lib/libexiv2.so"
                  "-DLIBXSLT_INCLUDE_DIR=${final.libxslt.dev}/include"
                  "-DLIBXSLT_LIBRARY=${final.libxslt.out}/lib/libxslt.so"
                  "-DLIBXSLT_EXSLT_LIBRARY=${final.libxslt.out}/lib/libexslt.so"
                  "-DLIBXSLT_XSLTPROC_EXECUTABLE=${final.libxslt.bin}/bin/xsltproc"
                ];

                passthru = (old.passthru or { }) // {
                  ffmpeg = ffmpegPkg;
                  frontend = baseName;
                  backend = backendName;
                };
              });

          kodi22WaylandFfmpeg8RkmppV4l2Request = mkKodi22Variant {
            baseName = "kodi-wayland";
            ffmpegPkg = final.ffmpeg_8-full-rkmpp-v4l2request;
            backendName = "ffmpeg8-rkmpp-v4l2request";
            hasV4l2Request = true;
          };
          kodi22X11Ffmpeg8RkmppV4l2Request = mkKodi22Variant {
            baseName = "kodi";
            ffmpegPkg = final.ffmpeg_8-full-rkmpp-v4l2request;
            backendName = "ffmpeg8-rkmpp-v4l2request";
            hasV4l2Request = true;
          };
          kodi22GbmFfmpeg8RkmppV4l2Request = mkKodi22Variant {
            baseName = "kodi-gbm";
            ffmpegPkg = final.ffmpeg_8-full-rkmpp-v4l2request;
            backendName = "ffmpeg8-rkmpp-v4l2request";
            hasV4l2Request = true;
          };

          kodi22WaylandFfmpeg8Rkmpp = mkKodi22Variant {
            baseName = "kodi-wayland";
            ffmpegPkg = final.ffmpeg_8-full-rkmpp;
            backendName = "ffmpeg8-rkmpp";
          };
          kodi22X11Ffmpeg8Rkmpp = mkKodi22Variant {
            baseName = "kodi";
            ffmpegPkg = final.ffmpeg_8-full-rkmpp;
            backendName = "ffmpeg8-rkmpp";
          };
          kodi22GbmFfmpeg8Rkmpp = mkKodi22Variant {
            baseName = "kodi-gbm";
            ffmpegPkg = final.ffmpeg_8-full-rkmpp;
            backendName = "ffmpeg8-rkmpp";
          };

          kodi22WaylandFfmpegRockchip = mkKodi22Variant {
            baseName = "kodi-wayland";
            ffmpegPkg = final.ffmpeg_8-full-rockchip;
            backendName = "ffmpeg-rockchip";
          };
          kodi22X11FfmpegRockchip = mkKodi22Variant {
            baseName = "kodi";
            ffmpegPkg = final.ffmpeg_8-full-rockchip;
            backendName = "ffmpeg-rockchip";
          };
          kodi22GbmFfmpegRockchip = mkKodi22Variant {
            baseName = "kodi-gbm";
            ffmpegPkg = final.ffmpeg_8-full-rockchip;
            backendName = "ffmpeg-rockchip";
          };
        in
        {
          "kodi_22-wayland-ffmpeg8-rkmpp-v4l2request" = kodi22WaylandFfmpeg8RkmppV4l2Request;
          "kodi_22-x11-ffmpeg8-rkmpp-v4l2request" = kodi22X11Ffmpeg8RkmppV4l2Request;
          "kodi_22-gbm-ffmpeg8-rkmpp-v4l2request" = kodi22GbmFfmpeg8RkmppV4l2Request;

          kodi_22_wayland_ffmpeg8_rkmpp_v4l2request = kodi22WaylandFfmpeg8RkmppV4l2Request;
          kodi_22_x11_ffmpeg8_rkmpp_v4l2request = kodi22X11Ffmpeg8RkmppV4l2Request;
          kodi_22_gbm_ffmpeg8_rkmpp_v4l2request = kodi22GbmFfmpeg8RkmppV4l2Request;

          "kodi_22-wayland-ffmpeg8-rkmpp" = kodi22WaylandFfmpeg8Rkmpp;
          "kodi_22-x11-ffmpeg8-rkmpp" = kodi22X11Ffmpeg8Rkmpp;
          "kodi_22-gbm-ffmpeg8-rkmpp" = kodi22GbmFfmpeg8Rkmpp;

          kodi_22_wayland_ffmpeg8_rkmpp = kodi22WaylandFfmpeg8Rkmpp;
          kodi_22_x11_ffmpeg8_rkmpp = kodi22X11Ffmpeg8Rkmpp;
          kodi_22_gbm_ffmpeg8_rkmpp = kodi22GbmFfmpeg8Rkmpp;

          "kodi_22-wayland-ffmpeg-rockchip" = kodi22WaylandFfmpegRockchip;
          "kodi_22-x11-ffmpeg-rockchip" = kodi22X11FfmpegRockchip;
          "kodi_22-gbm-ffmpeg-rockchip" = kodi22GbmFfmpegRockchip;

          kodi_22_wayland_ffmpeg_rockchip = kodi22WaylandFfmpegRockchip;
          kodi_22_x11_ffmpeg_rockchip = kodi22X11FfmpegRockchip;
          kodi_22_gbm_ffmpeg_rockchip = kodi22GbmFfmpegRockchip;

          "kodi_22-ffmpeg8-rkmpp-v4l2request" =
            builtins.getAttr "kodi_22-${effectiveKodiVariant}-ffmpeg8-rkmpp-v4l2request" final;
          kodi_22_ffmpeg8_rkmpp_v4l2request =
            builtins.getAttr "kodi_22-${effectiveKodiVariant}-ffmpeg8-rkmpp-v4l2request" final;

          "kodi_22-ffmpeg8-rkmpp" = builtins.getAttr "kodi_22-${effectiveKodiVariant}-ffmpeg8-rkmpp" final;
          kodi_22_ffmpeg8_rkmpp = builtins.getAttr "kodi_22-${effectiveKodiVariant}-ffmpeg8-rkmpp" final;

          "kodi_22-ffmpeg-rockchip" = builtins.getAttr "kodi_22-${effectiveKodiVariant}-ffmpeg-rockchip" final;
          kodi_22_ffmpeg_rockchip = builtins.getAttr "kodi_22-${effectiveKodiVariant}-ffmpeg-rockchip" final;

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
      ++ lib.optionals cfg.mpv.enable [ selectedMpvPkg ]
      ++ lib.optionals cfg.kodi.enable [ selectedKodiPkg ]
      ++ lib.optionals (cfg.kodi.enable && cfg.kodi.autostart.enable) [ kodiAutostartLauncher ];

    environment.shellAliases = lib.mkIf cfg.ffmpegTools.enable {
      "ffmpeg-v4l2request" = "${ffmpegWrapper}/bin/rock5c-ffmpeg-v4l2request";
      "ffprobe-v4l2request" = "${ffprobeWrapper}/bin/rock5c-ffprobe-v4l2request";
      "ffplay-v4l2request" = "${ffplayWrapper}/bin/rock5c-ffplay-v4l2request";
    };

    systemd.user.services.rock5c-kodi-autostart = lib.mkIf (cfg.kodi.enable && cfg.kodi.autostart.enable) {
      description = "Autostart Kodi after the graphical session is ready";
      after =
        [
          "graphical-session.target"
        ]
        ++ lib.optionals (lib.attrByPath [ "programs" "niri" "enable" ] false config) [ "niri.service" ];
      wants =
        [
          "graphical-session.target"
        ]
        ++ lib.optionals (lib.attrByPath [ "programs" "niri" "enable" ] false config) [ "niri.service" ];
      partOf = [ "graphical-session.target" ];
      wantedBy = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${kodiAutostartLauncher}/bin/rock5c-kodi-autostart";
        Restart = "on-failure";
        RestartSec = "3s";
      };
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
