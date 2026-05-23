{
  pkgs,
  lib,
  niri,
  wormhole-send,
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
  wormhole_send=${lib.getExe wormhole-send}
  mktemp=${lib.getExe' pkgs.coreutils "mktemp"}
  mkdir=${lib.getExe' pkgs.coreutils "mkdir"}
  date=${lib.getExe' pkgs.coreutils "date"}
  basename=${lib.getExe' pkgs.coreutils "basename"}
  cat=${lib.getExe' pkgs.coreutils "cat"}
  rm=${lib.getExe' pkgs.coreutils "rm"}
  sleep=${lib.getExe' pkgs.coreutils "sleep"}
  stat=${lib.getExe' pkgs.coreutils "stat"}

  screenshot_path() {
    local dir timestamp path suffix
    dir="$HOME/Pictures/Screenshots"
    $mkdir -p "$dir"

    timestamp=$($date '+%Y-%m-%dT%H:%M:%S%:z')
    path="$dir/satty-$timestamp.png"
    suffix=2

    while [ -e "$path" ]; do
      path="$dir/satty-$timestamp-$suffix.png"
      suffix=$((suffix + 1))
    done

    printf '%s\n' "$path"
  }

  watch_save_notifications() {
    local file state last_state seen name
    file=$1
    last_state=""
    seen=0
    name=$($basename "$file")

    while true; do
      if [ -e "$file" ]; then
        state=$($stat -c '%y:%s' "$file" 2>/dev/null || true)
        if [ -n "$state" ] && [ "$state" != "$last_state" ]; then
          if [ "$seen" -eq 0 ]; then
            $notify -t 5000 "Satty" "Saved $name"
            seen=1
          else
            $notify -t 5000 "Satty" "Already saved $name"
          fi
          last_state=$state
        fi
      fi
      $sleep 0.2
    done
  }

  annotate_file() {
    local input outfile watcher status
    input=$1
    outfile=$2

    watch_save_notifications "$outfile" &
    watcher=$!

    set +e
    $satty --fullscreen --disable-notifications --output-filename "$outfile" --copy-command "$wl_copy" -f "$input"
    status=$?
    set -e

    kill "$watcher" 2>/dev/null || true
    wait "$watcher" 2>/dev/null || true

    return "$status"
  }

  annotate_stdin() {
    local outfile tmpfile status
    outfile=$1
    tmpfile=$($mktemp /tmp/satty-screenshot-XXXXXX.png)
    $cat > "$tmpfile"
    set +e
    annotate_file "$tmpfile" "$outfile"
    status=$?
    set -e
    $rm -f "$tmpfile"
    return "$status"
  }

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

  if [ "''${1:-}" = "region" ]; then
    mode="Region"
  elif [ "''${1:-}" = "region-wormhole" ]; then
    mode="Region → Wormhole"
  else
    mode=$(printf 'Fullscreen\nFullscreen (3s delay)\nRegion\nRegion (3s delay)\nRegion → Wormhole\nFullscreen → Wormhole' | $fuzzel --dmenu --prompt "Screenshot: ") || exit 0
  fi

  case "$mode" in
    "Fullscreen")
      output=$(get_focused_output)
      outfile=$(screenshot_path)
      $grim -o "$output" - | annotate_stdin "$outfile"
      ;;
    "Fullscreen (3s delay)")
      output=$(get_focused_output)
      countdown
      outfile=$(screenshot_path)
      $grim -o "$output" - | annotate_stdin "$outfile"
      ;;
    "Region")
      geometry=$($slurp) || exit 0
      outfile=$(screenshot_path)
      $grim -g "$geometry" - | annotate_stdin "$outfile"
      ;;
    "Region (3s delay)")
      geometry=$($slurp) || exit 0
      countdown
      outfile=$(screenshot_path)
      $grim -g "$geometry" - | annotate_stdin "$outfile"
      ;;
    "Region → Wormhole")
      geometry=$($slurp) || exit 0
      tmpfile=$($mktemp /tmp/wormhole-screenshot-XXXXXX.png)
      $grim -g "$geometry" - | annotate_stdin "$tmpfile"
      $wormhole_send "$tmpfile" &
      ;;
    "Fullscreen → Wormhole")
      output=$(get_focused_output)
      tmpfile=$($mktemp /tmp/wormhole-screenshot-XXXXXX.png)
      $grim -o "$output" - | annotate_stdin "$tmpfile"
      $wormhole_send "$tmpfile" &
      ;;
  esac
''
