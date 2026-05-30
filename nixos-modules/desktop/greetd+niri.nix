{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dev.johnrinehart.desktop.greetd_niri;
  primaryUser = config.dev.johnrinehart.users.primary;

  # Cursor theme settings (single source of truth)
  xcursorTheme = "Adwaita";
  xcursorSize = 24;

  indentKdlLines =
    prefix: text:
    lib.concatStringsSep "\n" (
      map (line: if line == "" then "" else "${prefix}${line}") (lib.splitString "\n" text)
    );

  wormhole-send = pkgs.dev.johnrinehart.wormhole-send.override {
    notifyTimeout = cfg.wormholeNotifyTimeout;
  };

  niri-screenshot = pkgs.dev.johnrinehart.niri-screenshot.override {
    niri = config.programs.niri.package;
    inherit wormhole-send;
  };

  inherit (pkgs.dev.johnrinehart)
    brightness-notify
    niri-cycle-display-mode
    volume-notify
    ;

  clipboard-store-notify = pkgs.dev.johnrinehart.clipboard-store-notify;
  clipboard-watch = pkgs.dev.johnrinehart.clipboard-watch.override {
    inherit clipboard-store-notify;
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
      niri = {
        extraConfig = lib.mkOption {
          type = lib.types.lines;
          default = "";
          example = ''
            window-rule {
                match app-id="^org.example.App$"
                open-floating true
            }
          '';
          description = ''
            Extra raw KDL configuration appended to the generated niri
            configuration as top-level entries.
          '';
        };
        extraKeybindings = lib.mkOption {
          type = lib.types.lines;
          default = "";
          example = ''
            Mod+Shift+Return {
                spawn "alacritty"
            }
          '';
          description = ''
            Extra raw KDL keybindings appended inside the generated niri
            binds block.
          '';
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
      XCURSOR_THEME = xcursorTheme;
      XCURSOR_SIZE = toString xcursorSize;
    };

    programs.niri.enable = true;

    programs.niri.package = pkgs.dev.johnrinehart.niri;

    users.users.${primaryUser}.extraGroups = [ "seat" ];

    services.greetd.enable = true;
    # Raise the fd soft limit so children (waybar, etc.) don't hit the
    # default 1024 and fail with "Too many open files" on boot.
    systemd.services.greetd.serviceConfig.LimitNOFILE = "524288";
    services.greetd.settings.default_session = {
      command = "${lib.getExe' config.programs.niri.package "niri-session"}";
      user = primaryUser;
    };

    systemd.user.services.niri-display-mode-watch = {
      description = "Keep niri display mode recoverable after output disconnects";
      wantedBy = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      after = [
        "niri.service"
        "graphical-session.target"
      ];
      serviceConfig = {
        ExecStart = "${lib.getExe niri-cycle-display-mode} --watch";
        Restart = "always";
        RestartSec = "1s";
      };
    };

    environment.systemPackages =
      let
        myMako = pkgs.dev.johnrinehart.mako-with-etc-config;
        niri-gather-windows = pkgs.dev.johnrinehart.niri-gather-windows.override {
          niri = config.programs.niri.package;
        };
      in
      [
        niri-gather-windows
        niri-cycle-display-mode
        niri-screenshot
        brightness-notify
        volume-notify
        wormhole-send
        pkgs.magic-wormhole-rs
        pkgs.adwaita-icon-theme # cursor theme
        pkgs.alacritty
        pkgs.brightnessctl
        pkgs.cliphist
        pkgs.dev.johnrinehart.fuzzel_1_14_1
        pkgs.grim
        pkgs.hyprpaper
        pkgs.satty
        pkgs.slurp
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
        fuzzelDmenu = pkgs.dev.johnrinehart.fuzzel-dmenu.override {
          fuzzel = pkgs.dev.johnrinehart.fuzzel_1_14_1;
          niri = config.programs.niri.package;
        };
        niriBase = pkgs.replaceVarsWith {
          src = ./niri.kdl;
          replacements = {
            fuzzel_dmenu = lib.getExe fuzzelDmenu;
            clipboard_watch = lib.getExe clipboard-watch;
            lock_command = "${lib.getExe' pkgs.systemd "loginctl"} lock-session";
            suspend = "${lib.getExe' pkgs.systemd "systemctl"} suspend-then-hibernate";
            wl-kbptr = lib.getExe pkgs.wl-kbptr;
            brightness_notify = lib.getExe brightness-notify;
            niri_cycle_display_mode = lib.getExe niri-cycle-display-mode;
            niri_screenshot = lib.getExe niri-screenshot;
            volume_notify = lib.getExe volume-notify;
            wormhole_send = lib.getExe wormhole-send;
            xcursor_theme = xcursorTheme;
            extra_niri_config = cfg.niri.extraConfig;
            extra_niri_keybindings = lib.optionalString (
              cfg.niri.extraKeybindings != ""
            ) "\n${indentKdlLines "    " cfg.niri.extraKeybindings}";

            # PipeWire's wpctl resolves these at runtime. Passing null tells
            # replaceVarsWith that these @...@ tokens are intentional leftovers.
            DEFAULT_AUDIO_SINK = null;
            DEFAULT_AUDIO_SOURCE = null;
          };
        };
      in
      (pkgs.substitute {
        src = niriBase;
        substitutions = [
          "--replace-fail"
          "xcursor-size 24"
          "xcursor-size ${toString xcursorSize}"
        ];
      }).overrideAttrs
        (_: {
          checkPhase = null;
        });
    environment.etc."xdg/waybar".source = ./waybar;
    environment.etc."mako/config".source =
      (pkgs.replaceVars ./mako.conf {
        adwaita_icons = "${pkgs.adwaita-icon-theme}/share/icons/Adwaita";
        gnome_icons = "${pkgs.gnome-icon-theme}/share/icons/gnome";
      }).overrideAttrs
        (_: {
          checkPhase = null;
        });

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
