{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.dev.johnrinehart.desktop.greetd_niri;
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

    environment.systemPackages = [ pkgs.alacritty pkgs.xwayland-satellite pkgs.fuzzel pkgs.grim pkgs.mako pkgs.slurp pkgs.swaylock pkgs.xwayland-satellite pkgs.satty pkgs.waypaper pkgs.swaybg pkgs.waybar pkgs.brightnessctl pkgs.wlsunset pkgs.ueberzugpp ];

    environment.etc."niri/config.kdl".source = ./niri.kdl;

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

    programs.seahorse.enable = true;
    services.gnome.gnome-keyring.enable = true;
    security.pam.services.login.enableGnomeKeyring = true;
    security.pam.services.greetd.enableGnomeKeyring = true;
    security.pam.services.greetd-password.enableGnomeKeyring = true;
    services.dbus.packages = [ pkgs.gnome-keyring pkgs.gcr ];
    security.pam.services.gdm-password.enableGnomeKeyring = true;
  };
}

