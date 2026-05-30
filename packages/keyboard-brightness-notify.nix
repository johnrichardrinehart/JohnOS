{
  brightnessctl,
  gnome-icon-theme,
  lib,
  libnotify,
  writeShellApplication,
}:

writeShellApplication {
  name = "keyboard-brightness-notify";

  runtimeInputs = [
    brightnessctl
    libnotify
  ];

  text = ''
    set -euo pipefail

    icon="${gnome-icon-theme}/share/icons/gnome/48x48/devices/keyboard.png"

    notify() {
      notify-send \
        --app-name="JohnOS Keyboard" \
        --icon="$icon" \
        --expire-time=1400 \
        --hint=string:x-canonical-private-synchronous:keyboard-brightness \
        --hint="int:value:$hint_percent" \
        "$title" \
        "$body" \
        || true
    }

    find_keyboard_backlight() {
      devices=()
      while IFS= read -r line; do
        case "$line" in
          "Device '"*kbd_backlight*"'"*)
            device_name="''${line#Device \'}"
            devices+=("''${device_name%%\'*}")
            ;;
        esac
      done < <(brightnessctl --class=leds --list)

      for device in "''${devices[@]}"; do
        if [ "$device" = "framework_laptop::kbd_backlight" ]; then
          printf '%s\n' "$device"
          return 0
        fi
      done

      [ "''${#devices[@]}" -gt 0 ] || return 1
      printf '%s\n' "''${devices[0]}"
    }

    if ! device="$(find_keyboard_backlight)"; then
      title="Keyboard light"
      body="No keyboard backlight found"
      hint_percent=0
      notify
      exit 0
    fi

    action="''${1:-}"
    case "$action" in
      up)
        if ! brightnessctl --class=leds --device "$device" set +10%; then
          title="Keyboard light"
          body="Could not adjust backlight"
          hint_percent=0
          notify
          exit 0
        fi
        title="Keyboard light up"
        ;;
      down)
        if ! brightnessctl --class=leds --device "$device" set 10%-; then
          title="Keyboard light"
          body="Could not adjust backlight"
          hint_percent=0
          notify
          exit 0
        fi
        title="Keyboard light down"
        ;;
      *)
        printf 'usage: keyboard-brightness-notify up|down\n' >&2
        exit 2
        ;;
    esac

    status="$(brightnessctl --class=leds --device "$device" --machine-readable info)"
    IFS=, read -r _device _class _current percent_field _max <<< "$status"
    percent="''${percent_field%\%}"
    hint_percent="$percent"
    if [ "$hint_percent" -gt 100 ]; then
      hint_percent=100
    fi

    if [ "$percent" -eq 0 ]; then
      body="Off"
    elif [ "$percent" -lt 50 ]; then
      body="$percent% - soft keys"
    else
      body="$percent% - keys glowing"
    fi

    notify
  '';

  meta = with lib; {
    description = "Adjust keyboard backlight brightness and show an on-screen notification";
    license = licenses.mit;
    mainProgram = "keyboard-brightness-notify";
    platforms = platforms.linux;
  };
}
