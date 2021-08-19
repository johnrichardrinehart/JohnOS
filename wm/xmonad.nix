{ pkgs, ... }:

let
  extra = ''
    ${pkgs.systemd}/bin/systemctl --user start pulseaudio

    ################################################################################
    ########## Useful URLs from research
    ################################################################################
    # https://www.in-ulm.de/~mascheck/X11/xmodmap.html
    # https://wiki.archlinux.org/title/Xorg/Keyboard_configuration#Using_X_configuration_files
    # https://askubuntu.com/a/337431
    #
    ################################################################################
    ########## Helpful commands to find the keyboard map
    ################################################################################
    # setxkbmap -query
    # input list-props $NUMBER_YOURE_INTERESTED_IN
    # localctl list-x11-keymap models
    #
    #  setxkbmap -model sun_type7_usb -layout gb -option ctrl:swapcaps
    #  setxkbmap -model pc104 -layout cz,us -variant ,dvorak -option grp:alt_shift_toggle
    #  localectl [--no-convert] set-x11-keymap layout [model [variant [options]]]
  '';

  polybarOpts = ''
    ${pkgs.nitrogen}/bin/nitrogen --restore &
    ${pkgs.pasystray}/bin/pasystray &
    ${pkgs.gnome3.networkmanagerapplet}/bin/nm-applet --sm-disable --indicator &
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
