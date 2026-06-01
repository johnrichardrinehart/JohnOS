{
  pkgs,
  lib,
}:
pkgs.writeShellScriptBin "wormhole-send" ''
  set -euo pipefail

  wormhole=${lib.getExe pkgs.magic-wormhole-rs}
  notify=${lib.getExe' pkgs.libnotify "notify-send"}
  makoctl=${lib.getExe' pkgs.mako "makoctl"}
  wl_copy=${lib.getExe' pkgs.wl-clipboard "wl-copy"}
  stdbuf=${lib.getExe' pkgs.coreutils "stdbuf"}
  sed=${lib.getExe pkgs.gnused}
  grep=${lib.getExe pkgs.gnugrep}
  mktemp=${lib.getExe' pkgs.coreutils "mktemp"}
  seq=${lib.getExe' pkgs.coreutils "seq"}
  sleep=${lib.getExe' pkgs.coreutils "sleep"}

  file="''${1:-}"
  if [ -z "$file" ] || [ ! -f "$file" ]; then
    $notify -t 5000 "Wormhole" "Error: no file or file not found"
    exit 1
  fi

  notify_id=""

  pending_notification_is_active() {
    [ -n "$notify_id" ] || return 1
    $makoctl list -j 2>/dev/null | $grep -q "\"id\":[[:space:]]*$notify_id\\b"
  }

  show_pending_notification() {
    body="$1"

    if pending_notification_is_active; then
      $notify -a "Wormhole" -t 0 -r "$notify_id" "Wormhole" "$body" >/dev/null || true
    elif [ -z "$notify_id" ]; then
      notify_id=$($notify -a "Wormhole" -t 0 -p "Wormhole" "$body" 2>/dev/null || true)
    fi
  }

  finish_notification() {
    body="$1"

    if pending_notification_is_active; then
      $notify -a "Wormhole" -t 5000 -r "$notify_id" "Wormhole" "$body" >/dev/null || true
    fi
  }

  show_pending_notification "Starting transfer..."

  # Run wormhole-rs in background, strip ANSI escapes, capture output
  outfile=$($mktemp /tmp/wormhole-out-XXXXXX.txt)
  $stdbuf -oL $wormhole send "$file" 2>&1 | $sed -u 's/\x1b\[[0-9;]*m//g' > "$outfile" &
  wh_pid=$!

  # Poll for the wormhole code (appears within ~1s)
  code=""
  for i in $($seq 1 50); do
    code=$($grep -oP "code is: \K\S+" "$outfile" 2>/dev/null || true)
    if [ -n "$code" ]; then break; fi
    $sleep 0.1
  done

  if [ -n "$code" ]; then
    show_pending_notification "Code: $code"
    printf '%s' "$code" | $wl_copy
  else
    finish_notification "Failed to get wormhole code"
    kill $wh_pid 2>/dev/null || true
    rm -f "$outfile"
    exit 1
  fi

  # Wait for transfer to complete
  if wait $wh_pid; then
    status=0
  else
    status=$?
  fi
  rm -f "$outfile"

  if [ $status -eq 0 ]; then
    finish_notification "Transfer complete!"
  else
    finish_notification "Transfer failed or was cancelled"
  fi
''
