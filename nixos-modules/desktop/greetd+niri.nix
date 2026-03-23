{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.dev.johnrinehart.desktop.greetd_niri;
  niriRev = "b07bde3ee82dd73115e6b949e4f3f63695da35ea";
  niriShortRev = builtins.substring 0 8 niriRev;

  # Cursor theme settings (single source of truth)
  xcursorTheme = "Adwaita";
  xcursorSize = 24;

  niri-screenshot = pkgs.callPackage ./niri-screenshot.nix {
    niri = config.programs.niri.package;
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

    # Track upstream niri directly so compositor and Smithay fixes land quickly.
    programs.niri.package = pkgs.rustPlatform.buildRustPackage rec {
      pname = "niri";
      version = "unstable-${niriShortRev}";

      src = pkgs.fetchFromGitHub {
        owner = "niri-wm";
        repo = "niri";
        rev = niriRev;
        hash = "sha256-3bwx4WqCB06yfQIGB+OgIckOkEDyKxiTD5pOo4Xz2rI=";
      };

      cargoLock = {
        # Upstream niri already pins its Git dependencies in Cargo.lock.
        allowBuiltinFetchGit = true;
        lockFile = "${src}/Cargo.lock";
      };

      postPatch = ''
        patchShebangs resources/niri-session
        substituteInPlace resources/niri.service \
          --replace-fail 'ExecStart=niri' "ExecStart=$out/bin/niri"
      '';

      nativeBuildInputs = with pkgs; [
        installShellFiles
        pkg-config
        rustPlatform.bindgenHook
      ];

      buildInputs = with pkgs; [
        dbus
        libdisplay-info
        libglvnd
        libinput
        libxkbcommon
        libgbm
        pango
        pipewire
        seatd
        systemd
        wayland
      ];

      buildFeatures = [ "dbus" "xdp-gnome-screencast" "systemd" ];
      buildNoDefaultFeatures = true;

      checkFlags = [ "--skip=::egl" ];

      postInstall = ''
        install -Dm0644 resources/niri.desktop -t $out/share/wayland-sessions
        install -Dm0644 resources/niri-portals.conf -t $out/share/xdg-desktop-portal
        install -Dm0755 resources/niri-session -t $out/bin
        install -Dm0644 resources/niri{-shutdown.target,.service} -t $out/lib/systemd/user
      '';

      env = {
        RUSTFLAGS = toString (
          map (arg: "-C link-arg=" + arg) [
            "-Wl,--push-state,--no-as-needed"
            "-lEGL"
            "-lwayland-client"
            "-Wl,--pop-state"
          ]
        );
        NIRI_BUILD_COMMIT = niriShortRev;
      };

      passthru.providedSessions = [ "niri" ];

      meta.mainProgram = "niri";
    };

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
