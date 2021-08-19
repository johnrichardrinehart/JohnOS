{ pkgs, ... }:

let
  extra = ''
    ${pkgs.systemd}/bin/systemctl --user enable pulseaudio
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

    ## Set laptop keyboard to dvorak after xmonad screws up my Xorg.conf
    ${pkgs.xorg.setxkbmap}/bin/setxkbmap -device $(${pkgs.xorg.xinput}/bin/xinput | grep "AT Translated Set 2 keyboard" | cut -f 2 | cut -d = -f 2) -layout dvorak

    ## Fix linux kernel's ability to process audio 
    ## c.f. https://askubuntu.com/questions/1263178/20-04-no-speaker-audio-on-hp-spectre-x360-2020-15t-eb000
    ${pkgs.alsa-tools}/bin/hda-verb /dev/snd/hwC0D0 0x01 SET_GPIO_DIR 0x01
    ${pkgs.alsa-tools}/bin/hda-verb /dev/snd/hwC0D0 0x01 SET_GPIO_MASK 0x01
    ${pkgs.alsa-tools}/bin/hda-verb /dev/snd/hwC0D0 0x01 SET_GPIO_DATA 0x01
    ${pkgs.alsa-tools}/bin/hda-verb /dev/snd/hwC0D0 0x01 SET_GPIO_DATA 0x00
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
