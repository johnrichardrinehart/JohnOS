{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.dev.johnrinehart.desktop.greetd_niri;

  # Cursor theme settings (single source of truth)
  xcursorTheme = "Adwaita";
  xcursorSize = 24;

  wormhole-send = pkgs.callPackage ./wormhole-send.nix {
    notifyTimeout = cfg.wormholeNotifyTimeout;
  };

  niri-screenshot = pkgs.callPackage ./niri-screenshot.nix {
    niri = config.programs.niri.package;
    inherit wormhole-send;
  };

  # Shared PAM configuration for fingerprint + password authentication
  fprintPamConfig = ''
    # Account management
    account required pam_unix.so

    # Authentication management
    # Fingerprint: success→continue, timeout/unavailable→continue, wrong→reject immediately
    auth [success=ok ignore=ignore authinfo_unavail=ignore default=die] ${pkgs.fprintd}/lib/security/pam_fprintd.so timeout=5
    # Password is always required (do NOT use try_first_pass - we need fresh password for keyring)
    auth required pam_unix.so nullok
    auth optional ${pkgs.gnome-keyring}/lib/security/pam_gnome_keyring.so

    # Password management
    password sufficient pam_unix.so nullok yescrypt
    password optional ${pkgs.gnome-keyring}/lib/security/pam_gnome_keyring.so use_authtok

    # Session management
    session required pam_env.so conffile=/etc/pam/environment readenv=0
    session required pam_unix.so
    session required pam_loginuid.so
    session optional ${pkgs.systemd}/lib/security/pam_systemd.so
    session required pam_limits.so
    session optional ${pkgs.gnome-keyring}/lib/security/pam_gnome_keyring.so auto_start
  '';
in
{
  options = {
    dev.johnrinehart.desktop.greetd_niri = {
      enable = lib.mkEnableOption "greetd + niri";
      hypridle.enable = lib.mkEnableOption "hypridle integration" // {
        default = true;
      };
      wormholeNotifyTimeout = lib.mkOption {
        type = lib.types.int;
        default = 15000;
        description = "Timeout in ms for wormhole code notifications (0 = persistent)";
      };
    }
    // {
      default = false;
    };
  };

  config = lib.mkIf cfg.enable {
    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
      XCURSOR_THEME = xcursorTheme;
      XCURSOR_SIZE = toString xcursorSize;
    };

    programs.niri.enable = true;

    programs.niri.package = pkgs."niri-26.04";

    users.users.john.extraGroups = [ "seat" ];

    services.greetd.enable = true;
    # Raise the fd soft limit so children (waybar, etc.) don't hit the
    # default 1024 and fail with "Too many open files" on boot.
    systemd.services.greetd.serviceConfig.LimitNOFILE = "524288";
    services.greetd.settings.default_session = {
      command = "${lib.getExe' config.programs.niri.package "niri-session"}";
      user = "john";
    };

    environment.systemPackages =
      let
        myMako = pkgs.mako.overrideAttrs (old: {
          patches = old.patches or [ ] ++ [ ./0001-feat-support-etc-mako-config.patch ];
        });
        niri-gather-windows = pkgs.callPackage ./niri-gather-windows.nix {
          niri = config.programs.niri.package;
        };
      in
      [
        niri-gather-windows
        niri-screenshot
        wormhole-send
        pkgs.magic-wormhole-rs
        pkgs.adwaita-icon-theme # cursor theme
        pkgs.alacritty
        pkgs.brightnessctl
        pkgs.cliphist
        pkgs.fuzzel
        pkgs.grim
        pkgs.hyprpaper
        pkgs.satty
        pkgs.slurp
        pkgs.swaylock
        pkgs.waybar
        pkgs.wl-clip-persist
        pkgs.wl-clipboard
        pkgs.wlsunset
        pkgs.xwayland-satellite
        # (builtins.getFlake "github:niri-wm/niri?rev=${niriRev}").packages.${pkgs.stdenv.hostPlatform.system}.niri
      ]
      ++ [
        myMako
      ];

    environment.etc."niri/config.kdl".source =
      let
        fuzzelDmenu = pkgs.callPackage ./fuzzel_dmenu/fuzzel_dmenu.nix { };
      in
      (pkgs.replaceVars ./niri.kdl {
        fuzzel_dmenu = lib.getExe fuzzelDmenu;
        lock_command = "${lib.getExe' pkgs.systemd "loginctl"} lock-session";
        suspend = "${lib.getExe' pkgs.systemd "systemctl"} suspend-then-hibernate";
        wl-kbptr = lib.getExe pkgs.wl-kbptr;
        niri_screenshot = lib.getExe niri-screenshot;
        wormhole_send = lib.getExe wormhole-send;
        obs-cmd = lib.getExe pkgs.obs-cmd;
        xcursor_theme = xcursorTheme;
        xcursor_size = toString xcursorSize;
      }).overrideAttrs
        (_: {
          checkPhase = null;
        });
    environment.etc."xdg/waybar".source = ./waybar;
    environment.etc."mako/config".source = ./mako.conf;

    # Custom PAM config: fingerprint as first factor (rejects bad
    # fingerprints), then mandatory password - applied to authentication
    # services
    security.pam.services =
      lib.genAttrs
        [
          "greetd"
          "hyprlock"
          "login"
          "polkit-1"
          "sudo"
          "swaylock"
        ]
        (_: {
          enableGnomeKeyring = true;
          text = fprintPamConfig;
        });

    services.hypridle.enable = true;
    programs.hyprlock.enable = true;
  };
}
