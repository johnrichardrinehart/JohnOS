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

  wormhole-send = pkgs.callPackage ./wormhole-send.nix {
    notifyTimeout = cfg.wormholeNotifyTimeout;
  };

  niri-screenshot = pkgs.callPackage ./niri-screenshot.nix {
    niri = config.programs.niri.package;
    inherit wormhole-send;
  };

  niri-cycle-display-mode = pkgs.callPackage ./niri-cycle-display-mode.nix {
    niri = config.programs.niri.package;
  };

  clipboard-store-notify = pkgs.writeShellScriptBin "clipboard-store-notify" ''
    set -euo pipefail

    cliphist=${lib.getExe pkgs.cliphist}
    notify=${lib.getExe' pkgs.libnotify "notify-send"}
    cat=${lib.getExe' pkgs.coreutils "cat"}
    mkdir=${lib.getExe' pkgs.coreutils "mkdir"}
    mktemp=${lib.getExe' pkgs.coreutils "mktemp"}
    rm=${lib.getExe' pkgs.coreutils "rm"}
    sha256sum=${lib.getExe' pkgs.coreutils "sha256sum"}
    cut=${lib.getExe' pkgs.coreutils "cut"}

    state_dir="''${XDG_RUNTIME_DIR:-/tmp}/johnos-clipboard-watch"
    state_file="$state_dir/last-payload.sha256"
    tmpfile=$($mktemp "''${XDG_RUNTIME_DIR:-/tmp}/clipboard-watch-XXXXXX")
    trap '$rm -f "$tmpfile"' EXIT

    $cat > "$tmpfile"

    case "''${CLIPBOARD_STATE:-data}" in
      data)
        ;;
      *)
        $rm -f "$state_file"
        exit 0
        ;;
    esac

    $cliphist store < "$tmpfile"

    $mkdir -p "$state_dir"
    hash=$($sha256sum "$tmpfile" | $cut -d ' ' -f 1)
    previous_hash=""
    if [ -f "$state_file" ]; then
      previous_hash=$($cat "$state_file")
    fi

    [ "$hash" != "$previous_hash" ] || exit 0

    printf '%s\n' "$hash" > "$state_file"
    $notify -t 1500 "Clipboard" "Updated"
  '';

  clipboard-watch = pkgs.writeShellScriptBin "clipboard-watch" ''
    set -euo pipefail

    wl_paste=${lib.getExe' pkgs.wl-clipboard "wl-paste"}

    $wl_paste --watch ${lib.getExe clipboard-store-notify}
  '';

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

    users.users.${primaryUser}.extraGroups = [ "seat" ];

    services.greetd.enable = true;
    # Raise the fd soft limit so children (waybar, etc.) don't hit the
    # default 1024 and fail with "Too many open files" on boot.
    systemd.services.greetd.serviceConfig.LimitNOFILE = "524288";
    services.greetd.settings.default_session = {
      command = "${lib.getExe' config.programs.niri.package "niri-session"}";
      user = primaryUser;
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
        niri-cycle-display-mode
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
        niriBase = pkgs.replaceVarsWith {
          src = ./niri.kdl;
          replacements = {
            fuzzel_dmenu = lib.getExe fuzzelDmenu;
            clipboard_watch = lib.getExe clipboard-watch;
            lock_command = "${lib.getExe' pkgs.systemd "loginctl"} lock-session";
            suspend = "${lib.getExe' pkgs.systemd "systemctl"} suspend-then-hibernate";
            wl-kbptr = lib.getExe pkgs.wl-kbptr;
            niri_cycle_display_mode = lib.getExe niri-cycle-display-mode;
            niri_screenshot = lib.getExe niri-screenshot;
            wormhole_send = lib.getExe wormhole-send;
            xcursor_theme = xcursorTheme;

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
