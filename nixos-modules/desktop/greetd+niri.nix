{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.dev.johnrinehart.desktop.greetd_niri;

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
    environment.sessionVariables.NIXOS_OZONE_WL = "1";

    programs.niri.enable = true;

    # Use custom niri fork - build from scratch since overriding cargoHash requires rebuilding
    programs.niri.package = pkgs.rustPlatform.buildRustPackage {
      pname = "niri";
      version = "unstable-2024-12-fork";

      src = pkgs.fetchFromGitHub {
        owner = "johnrichardrinehart";
        repo = "niri";
        rev = "e1b394ce9ad51a6892c8df4eb15605cb71f7dc0a";
        hash = "sha256-gvCF+DaFeR2siWMdl3reM9tuvuNewJW5TiafRGvaH9I=";
      };

      cargoHash = "sha256-CXRI9LBmP2YXd2Kao9Z2jpON+98n2h7m0zQVVTuwqYQ=";

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
        NIRI_BUILD_COMMIT = "a84a8ceb";
      };

      passthru.providedSessions = [ "niri" ];

      meta.mainProgram = "niri";
    };

    users.users.john.extraGroups = [ "seat" ];

    services.greetd.enable = true;
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
        # (builtins.getFlake "github:johnrichardrinehart/niri?rev=a84a8ceb5882cca5b26c6caf9e582111a3772634").packages.${pkgs.stdenv.hostPlatform.system}.niri
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
