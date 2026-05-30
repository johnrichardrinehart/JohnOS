{
  brightnessctl,
  gnome-icon-theme,
  lib,
  libnotify,
  writeShellApplication,
}:

writeShellApplication {
  name = "brightness-notify";

  runtimeInputs = [
    brightnessctl
    libnotify
  ];

  text = ''
    set -euo pipefail

    action="''${1:-}"
    case "$action" in
      up)
        brightnessctl --class=backlight set +4%
        title="Brightness up"
        ;;
      down)
        brightnessctl --class=backlight set 4%-
        title="Brightness down"
        ;;
      *)
        printf 'usage: brightness-notify up|down\n' >&2
        exit 2
        ;;
    esac

    status="$(brightnessctl --class=backlight --machine-readable info)"
    IFS=, read -r _device _class _current percent_field _max <<< "$status"
    percent="''${percent_field%\%}"
    hint_percent="$percent"
    if [ "$hint_percent" -gt 100 ]; then
      hint_percent=100
    fi

    if [ "$percent" -lt 25 ]; then
      icon="${gnome-icon-theme}/share/icons/gnome/48x48/status/stock_weather-night-clear.png"
      body="$percent% - moonlit"
    elif [ "$percent" -lt 75 ]; then
      icon="${gnome-icon-theme}/share/icons/gnome/48x48/status/weather-few-clouds-night.png"
      body="$percent% - easy glow"
    else
      icon="${gnome-icon-theme}/share/icons/gnome/48x48/status/sunny.png"
      body="$percent% - bright and clear"
    fi

    notify-send \
      --app-name="JohnOS Brightness" \
      --icon="$icon" \
      --expire-time=1400 \
      --hint=string:x-canonical-private-synchronous:brightness \
      --hint="int:value:$hint_percent" \
      "$title" \
      "$body" \
      || true
  '';

  meta = with lib; {
    description = "Adjust the default backlight brightness and show an on-screen notification";
    license = licenses.mit;
    mainProgram = "brightness-notify";
    platforms = platforms.linux;
  };
}
