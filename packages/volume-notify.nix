{
  gnome-icon-theme,
  lib,
  libnotify,
  wireplumber,
  writeShellApplication,
}:

writeShellApplication {
  name = "volume-notify";

  runtimeInputs = [
    libnotify
    wireplumber
  ];

  text = ''
    set -euo pipefail

    read_volume() {
      status="$(wpctl get-volume @DEFAULT_AUDIO_SINK@)"
      volume="''${status#Volume: }"
      volume="''${volume%% *}"

      if [[ "$volume" == *.* ]]; then
        whole="''${volume%%.*}"
        fraction="''${volume#*.}"
      else
        whole="$volume"
        fraction="0"
      fi

      fraction="''${fraction}00"
      percent=$((10#$whole * 100 + 10#''${fraction:0:2}))
      hint_percent="$percent"
      if [ "$hint_percent" -gt 100 ]; then
        hint_percent=100
      fi
    }

    icon_for_percent() {
      icon="${gnome-icon-theme}/share/icons/gnome/48x48/status/audio-volume-high.png"
      if [ "$percent" -eq 0 ] || [[ "$status" == *"[MUTED]"* ]]; then
        icon="${gnome-icon-theme}/share/icons/gnome/48x48/status/audio-volume-muted.png"
      elif [ "$percent" -lt 34 ]; then
        icon="${gnome-icon-theme}/share/icons/gnome/48x48/status/audio-volume-low.png"
      elif [ "$percent" -lt 67 ]; then
        icon="${gnome-icon-theme}/share/icons/gnome/48x48/status/audio-volume-medium.png"
      fi
    }

    action="''${1:-}"
    case "$action" in
      up)
        wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 0.1+
        read_volume
        title="Volume up"
        body="$percent% - turning it up"
        icon_for_percent
        ;;
      down)
        wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1-
        read_volume
        title="Volume down"
        body="$percent% - easing back"
        icon_for_percent
        ;;
      mute)
        wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
        read_volume
        if [[ "$status" == *"[MUTED]"* ]]; then
          title="Muted"
          body="Sound tucked away"
          icon="${gnome-icon-theme}/share/icons/gnome/48x48/status/audio-volume-muted.png"
          hint_percent=0
        else
          title="Unmuted"
          body="$percent% - sound is back"
          icon_for_percent
        fi
        ;;
      *)
        printf 'usage: volume-notify up|down|mute\n' >&2
        exit 2
        ;;
    esac

    notify-send \
      --app-name="JohnOS Audio" \
      --icon="$icon" \
      --expire-time=1400 \
      --hint=string:x-canonical-private-synchronous:volume \
      --hint="int:value:$hint_percent" \
      "$title" \
      "$body" \
      || true
  '';

  meta = with lib; {
    description = "Adjust the default PipeWire sink volume and show an on-screen notification";
    license = licenses.mit;
    mainProgram = "volume-notify";
    platforms = platforms.linux;
  };
}
