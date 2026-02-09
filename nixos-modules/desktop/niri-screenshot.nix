{
  pkgs,
  lib,
  niri,
}:
pkgs.writeShellScriptBin "niri-screenshot" ''
  set -euo pipefail

  grim=${lib.getExe pkgs.grim}
  slurp=${lib.getExe pkgs.slurp}
  satty=${lib.getExe pkgs.satty}
  wl_copy=${lib.getExe' pkgs.wl-clipboard "wl-copy"}
  notify=${lib.getExe pkgs.libnotify}
  niri=${lib.getExe niri}
  jq=${lib.getExe pkgs.jq}
  fuzzel=${lib.getExe pkgs.fuzzel}

  get_focused_output() {
    $niri msg --json focused-output | $jq -r '.name'
  }

  countdown() {
    local id
    id=$($notify -p -t 1000 "Screenshot" "3...")
    sleep 1
    $notify -r "$id" -t 1000 "Screenshot" "2..."
    sleep 1
    $notify -r "$id" -t 900 "Screenshot" "1..."
    sleep 1
  }

  mode=$(printf 'Fullscreen\nFullscreen (3s delay)\nRegion (3s delay)' | $fuzzel --dmenu --prompt "Screenshot: ") || exit 0

  case "$mode" in
    "Fullscreen")
      output=$(get_focused_output)
      $grim -o "$output" - | $satty --fullscreen --copy-command "$wl_copy" -f -
      ;;
    "Fullscreen (3s delay)")
      output=$(get_focused_output)
      countdown
      $grim -o "$output" - | $satty --fullscreen --copy-command "$wl_copy" -f -
      ;;
    "Region (3s delay)")
      geometry=$($slurp) || exit 0
      countdown
      $grim -g "$geometry" - | $satty --fullscreen --copy-command "$wl_copy" -f -
      ;;
  esac
''
