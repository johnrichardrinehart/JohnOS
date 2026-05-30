{
  gnome-icon-theme,
  lib,
  libnotify,
  niri,
  writeShellApplication,
}:

writeShellApplication {
  name = "monitor-power-notify";

  runtimeInputs = [
    libnotify
    niri
  ];

  text = ''
    set -euo pipefail

    notify-send \
      --app-name="JohnOS Display" \
      --icon="${gnome-icon-theme}/share/icons/gnome/48x48/devices/video-display.png" \
      --expire-time=900 \
      --hint=string:x-canonical-private-synchronous:display-power \
      "Displays off" \
      "Wake with keyboard or pointer" \
      || true

    niri msg action power-off-monitors
  '';

  meta = with lib; {
    description = "Power off niri monitors and show an on-screen notification";
    license = licenses.mit;
    mainProgram = "monitor-power-notify";
    platforms = platforms.linux;
  };
}
