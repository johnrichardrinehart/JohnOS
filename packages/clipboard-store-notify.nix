{
  cliphist,
  coreutils,
  lib,
  libnotify,
  writeShellScriptBin,
}:

writeShellScriptBin "clipboard-store-notify" ''
  set -euo pipefail

  cliphist=${lib.getExe cliphist}
  notify=${lib.getExe' libnotify "notify-send"}
  cat=${lib.getExe' coreutils "cat"}
  mkdir=${lib.getExe' coreutils "mkdir"}
  mktemp=${lib.getExe' coreutils "mktemp"}
  rm=${lib.getExe' coreutils "rm"}
  sha256sum=${lib.getExe' coreutils "sha256sum"}
  cut=${lib.getExe' coreutils "cut"}

  state_dir="''${XDG_RUNTIME_DIR:-/tmp}/johnos-clipboard-watch"
  state_file="$state_dir/last-payload.sha256"
  tmpfile=$($mktemp "''${XDG_RUNTIME_DIR:-/tmp}/clipboard-watch-XXXXXX")
  trap '$rm -f "$tmpfile"' EXIT

  $cat > "$tmpfile"

  case "''${CLIPBOARD_STATE:-data}" in
    data)
      ;;
    *)
      $rm -f "$state_file"
      exit 0
      ;;
  esac

  $cliphist store < "$tmpfile"

  $mkdir -p "$state_dir"
  hash=$($sha256sum "$tmpfile" | $cut -d ' ' -f 1)
  previous_hash=""
  if [ -f "$state_file" ]; then
    previous_hash=$($cat "$state_file")
  fi

  [ "$hash" != "$previous_hash" ] || exit 0

  printf '%s\n' "$hash" > "$state_file"
  $notify -t 1500 "Clipboard" "Updated"
''
