{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dev.johnrinehart.xorg;
in
{
  options = {
    dev.johnrinehart.xorg = {
      enable = lib.mkEnableOption "John's opinionated Xorg config";
    }
    // {
      default = false;
    };
  };

  config = lib.mkIf cfg.enable {
    services.displayManager = {
      # https://www.reddit.com/r/unixporn/comments/a7rg63/oc_a_tiny_riceable_lightdm_greeter/eckzt15?utm_source=share&utm_medium=web2x&context=3
      defaultSession = "none+xmonad"; # TODO: figure out a way to use another string besides default
    };

    services.xserver = {
      enable = true;

      exportConfiguration = true; # https://github.com/NixOS/nixpkgs/issues/19629#issuecomment-368051434

      displayManager = {
        lightdm.greeters.enso.enable = true;
        lightdm.extraConfig = ''
          logind-check-graphical = true
        '';
        sessionCommands = ''
          ${lib.getExe pkgs.feh} --bg-fill ${../../static/ocean.jpg} # configure background
          ${lib.getExe pkgs.xorg.xsetroot} -cursor_name left_ptr # configure pointer
          ${lib.getExe pkgs.networkmanagerapplet} --sm-disable --indicator &
          ${pkgs.pasystray}/bin/pasystray &
          ${pkgs.networkmanagerapplet}/bin/nm-applet --sm-disable --indicator &
        '';
      };
    };

    environment.systemPackages = [
      pkgs.autorandr
      pkgs.flameshot
      pkgs.xclip
      pkgs.feh
      pkgs.multilockscreen
      pkgs.dunst
    ];
  };
}
