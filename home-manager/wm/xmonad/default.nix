args @ { pkgs, ... }:

let
  extra = ''
    ${pkgs.feh}/bin/feh --bg-fill ${../../../static/ocean.jpg} # configure background
    ${pkgs.xorg.xsetroot}/bin/xsetroot -cursor_name left_ptr # configure pointer
  '';

  polybarOpts = ''
    ${pkgs.nitrogen}/bin/nitrogen --restore &
    ${pkgs.pasystray}/bin/pasystray &
    ${pkgs.networkmanagerapplet}/bin/nm-applet --sm-disable --indicator &
  '';

  configureKeyboards = ''
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

    LAPTOP_KBD="AT Translated Set 2 keyboard";
    LAPTOP_KBD_ID=$(${pkgs.xorg.xinput}/bin/xinput | grep "''${LAPTOP_KBD}" | cut -f 2 | cut -d = -f 2);
    ${pkgs.xorg.setxkbmap}/bin/setxkbmap -device $LAPTOP_KBD_ID -layout us -variant dvorak;
    ${pkgs.xorg.setxkbmap}/bin/setxkbmap -device 8 -layout us
      }

    configureKeyboards;
  '';

  configureMonitors =
    let
      laptopResolution = "2256x1504";
    in
    ''
        configureMonitors() {
        LAP_MONITOR="eDP-1"
        ${pkgs.xorg.xrandr}/bin/xrandr --output "''${LAP_MONITOR}" --mode ${laptopResolution}
        ${pkgs.xorg.xrandr}/bin/xrandr --setprovideroutputsource 1 0

      # looks like: https://bugs.freedesktop.org/show_bug.cgi?id=110830
      # which referencese: https://gist.github.com/szpak/71081b40217fb27c7a565b8c7b972067
      # consider filing a bug at: https://gitlab.freedesktop.org/drm/nouveau/
        for monitor in $(${pkgs.xorg.xrandr}/bin/xrandr | grep " connected" | cut -f1 -d " "); do
        if [[ "''${monitor}" != "''${LAP_MONITOR}" ]]
        then
          ${pkgs.xorg.xrandr}/bin/xrandr --output "''${monitor}" --mode 2560x1440 --right-of "''${LAP_MONITOR}"
        fi
        done
        }

        configureMonitors;
    '';
in
{
  xsession = {
    initExtra = extra + polybarOpts + configureKeyboards + configureMonitors;

    windowManager.xmonad = {
      enable = true;
      enableContribAndExtras = true;

      extraPackages = hp: [
        hp.dbus
        hp.monad-logger
      ];

      config = ./config.hs;
    };
  };
}
