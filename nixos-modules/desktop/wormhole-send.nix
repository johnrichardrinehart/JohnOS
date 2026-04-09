{
  pkgs,
  lib,
  notifyTimeout ? 15000,
}:
pkgs.writeShellScriptBin "wormhole-send" ''
  set -euo pipefail

  wormhole=${lib.getExe pkgs.magic-wormhole-rs}
  notify=${lib.getExe' pkgs.libnotify "notify-send"}
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

  $notify -t 3000 "Wormhole" "Starting transfer..."

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
    $notify -t ${toString notifyTimeout} "Wormhole" "Code: $code"
    printf '%s' "$code" | $wl_copy
  else
    $notify -t 5000 "Wormhole" "Failed to get wormhole code"
    kill $wh_pid 2>/dev/null || true
    rm -f "$outfile"
    exit 1
  fi

  # Wait for transfer to complete
  wait $wh_pid
  status=$?
  rm -f "$outfile"

  if [ $status -eq 0 ]; then
    $notify -t 5000 "Wormhole" "Transfer complete!"
  else
    $notify -t 5000 "Wormhole" "Transfer failed or was cancelled"
  fi
''
