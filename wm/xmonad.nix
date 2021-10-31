args @ { pkgs, ... }:

let
  extra = ''
    configureKeyboards() {
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

        export LAPTOP_KBD="AT Translated Set 2 keyboard"
        ${pkgs.xorg.setxkbmap}/bin/setxkbmap -device $(${pkgs.xorg.xinput}/bin/xinput | grep "''${LAPTOP_KBD}" | cut -f 2 | cut -d = -f 2) -layout dvorak
    }

    configureMonitors() {
      LAP_MONITOR="eDP-1"
      ${pkgs.xorg.xrandr}/bin/xrandr --output "''${LAP_MONITOR}" --mode 1920x1080
      ${pkgs.xorg.xrandr}/bin/xrandr --setprovideroutputsource 1 0

      # looks like: https://bugs.freedesktop.org/show_bug.cgi?id=110830
      # which referencese: https://gist.github.com/szpak/71081b40217fb27c7a565b8c7b972067
      # consider filing a bug at: https://gitlab.freedesktop.org/drm/nouveau/
      for monitor in $(${pkgs.xorg.xrandr}/bin/xrandr | grep " connected" | cut -f1 -d " "); do
        if [[ "''${monitor}" != "''${LAP_MONITOR}" ]]
        then
          ${pkgs.xorg.xrandr}/bin/xrandr --output "''${monitor}" --mode 2560x1440 --primary --above "''${LAP_MONITOR}"
        fi
      done
    }

    configureAudio() {
        ## Fix linux kernel's ability to process audio
        ## c.f. https://askubuntu.com/questions/1263178/20-04-no-speaker-audio-on-hp-spectre-x360-2020-15t-eb000
        sudo ${pkgs.alsa-tools}/bin/hda-verb /dev/snd/hwC0D0 0x01 SET_GPIO_DIR 0x01
        sudo ${pkgs.alsa-tools}/bin/hda-verb /dev/snd/hwC0D0 0x01 SET_GPIO_MASK 0x01
        sudo ${pkgs.alsa-tools}/bin/hda-verb /dev/snd/hwC0D0 0x01 SET_GPIO_DATA 0x01
        sudo ${pkgs.alsa-tools}/bin/hda-verb /dev/snd/hwC0D0 0x01 SET_GPIO_DATA 0x00

        ${pkgs.systemd}/bin/systemctl --user enable pulseaudio
        ${pkgs.systemd}/bin/systemctl --user start pulseaudio
    }

    configureKeyboards
    configureAudio
    configureMonitors

    ${pkgs.feh}/bin/feh --bg-fill ${args.photo}/bin/ocean.jpg # configure background
    ${pkgs.xorg.xsetroot}/bin/xsetroot -cursor_name left_ptr # configure pointer
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
