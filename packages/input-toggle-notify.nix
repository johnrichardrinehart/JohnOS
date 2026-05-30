{
  gnome-icon-theme,
  lib,
  libnotify,
  niri,
  writeShellApplication,
}:

writeShellApplication {
  name = "input-toggle-notify";

  runtimeInputs = [
    libnotify
    niri
  ];

  text = ''
    set -euo pipefail

    action="''${1:-}"
    case "$action" in
      shortcuts-inhibit)
        notify-send \
          --app-name="JohnOS Input" \
          --icon="${gnome-icon-theme}/share/icons/gnome/48x48/devices/keyboard.png" \
          --expire-time=1400 \
          --hint=string:x-canonical-private-synchronous:input-toggle \
          "Shortcut passthrough toggled" \
          "Focused app shortcut handling changed" \
          || true

        niri msg action toggle-keyboard-shortcuts-inhibit
        ;;
      *)
        printf 'usage: input-toggle-notify shortcuts-inhibit\n' >&2
        exit 2
        ;;
    esac
  '';

  meta = with lib; {
    description = "Toggle niri input actions and show an on-screen notification";
    license = licenses.mit;
    mainProgram = "input-toggle-notify";
    platforms = platforms.linux;
  };
}
