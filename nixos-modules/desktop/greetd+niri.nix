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
    # Password is always required
    auth required pam_unix.so try_first_pass nullok
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

    users.users.john.extraGroups = [ "seat" ];

    services.greetd.enable = true;
    services.greetd.settings.default_session.command = "${lib.getExe pkgs.tuigreet}";
    services.greetd.useTextGreeter = true;

    environment.systemPackages = [ pkgs.alacritty pkgs.xwayland-satellite pkgs.fuzzel pkgs.grim pkgs.mako pkgs.slurp pkgs.swaylock pkgs.xwayland-satellite pkgs.satty pkgs.waypaper pkgs.swaybg pkgs.waybar pkgs.brightnessctl pkgs.wlsunset pkgs.wl-clip-persist pkgs.wl-clipboard pkgs.cliphist ];

    environment.etc."niri/config.kdl".source = ./niri.kdl;
    environment.etc."xdg/waybar".source = ./waybar;

    systemd.user.services.swaybg = {
      enable = true;
      after = [ "graphical-session.target" ];
      requisite = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      path = [ pkgs.swaybg ];
      serviceConfig = {
        Type = "forking";
        Restart = "on-failure";
      };
      script = ''
        ${lib.getExe pkgs.waypaper} --fill fill --wallpaper ${../../static/ocean.jpg} --monitor All --backend swaybg &
      '';
    };

    services.gnome.gnome-keyring.enable = true;

    # Custom PAM config: fingerprint as first factor (rejects bad fingerprints),
    # then mandatory password - applied to greetd, sudo, and TTY logins
    security.pam.services.greetd = {
      enableGnomeKeyring = true;
      text = fprintPamConfig;
    };

    security.pam.services.sudo = {
      enableGnomeKeyring = true;
      text = fprintPamConfig;
    };

    security.pam.services.login = {
      enableGnomeKeyring = true;
      text = fprintPamConfig;
    };
  };
}

