args @ { pkgs, ... }:

let
  extra = ''
    ${pkgs.feh}/bin/feh --bg-fill ${args.photo}/bin/ocean.jpg # configure background
    ${pkgs.xorg.xsetroot}/bin/xsetroot -cursor_name left_ptr # configure pointer
  '';

  polybarOpts = ''
    ${pkgs.nitrogen}/bin/nitrogen --restore &
    ${pkgs.pasystray}/bin/pasystray &
    ${pkgs.networkmanagerapplet}/bin/nm-applet --sm-disable --indicator &
  '';
in
{
  initExtra = extra + polybarOpts;

  xmonad = {
    enable = true;
    enableContribAndExtras = true;

    extraPackages = hp: [
      hp.dbus
      hp.monad-logger
    ];

    config = ./config.hs;
  };
}
