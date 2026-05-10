{
  lib,
  pkgs,
  niri,
}:

pkgs.writeShellScriptBin "niri-cycle-display-mode" ''
  set -euo pipefail

  niri=${lib.getExe niri}
  jq=${lib.getExe pkgs.jq}
  wl_mirror=${lib.getExe' pkgs.wl-mirror "wl-mirror"}
  mkdir=${lib.getExe' pkgs.coreutils "mkdir"}
  nohup=${lib.getExe' pkgs.coreutils "nohup"}
  rm=${lib.getExe' pkgs.coreutils "rm"}
  sleep=${lib.getExe' pkgs.coreutils "sleep"}

  outputs_json="$($niri msg --json outputs)"
  mapfile -t outputs < <($jq -r 'to_entries | map(.value.name // .key) | sort | .[]' <<< "$outputs_json")
  mapfile -t active_outputs < <($jq -r 'to_entries[] | select(.value.logical != null) | .value.name // .key' <<< "$outputs_json")

  if [ "''${#outputs[@]}" -le 1 ]; then
    exit 0
  fi

  state_dir="''${XDG_RUNTIME_DIR:-/tmp}/johnos-niri-display-mode"
  mirror_pid_file="$state_dir/wl-mirror.pids"

  is_internal_output() {
    case "$1" in
      eDP-*|LVDS-*|DSI-*) return 0 ;;
      *) return 1 ;;
    esac
  }

  single_outputs=()
  for output in "''${outputs[@]}"; do
    if ! is_internal_output "$output"; then
      single_outputs+=("$output")
    fi
  done
  for output in "''${outputs[@]}"; do
    if is_internal_output "$output"; then
      single_outputs+=("$output")
    fi
  done

  first_single_target() {
    printf '%s\n' "''${single_outputs[0]}"
  }

  next_single_target() {
    current="$1"

    for i in "''${!single_outputs[@]}"; do
      if [ "''${single_outputs[$i]}" = "$current" ]; then
        next_index=$((i + 1))
        if [ "$next_index" -lt "''${#single_outputs[@]}" ]; then
          printf '%s\n' "''${single_outputs[$next_index]}"
          return 0
        fi

        return 1
      fi
    done

    first_single_target
  }

  mirror_is_active() {
    [ -f "$mirror_pid_file" ] || return 1

    while IFS= read -r pid; do
      [ -n "$pid" ] || continue
      if kill -0 "$pid" 2>/dev/null; then
        return 0
      fi
    done < "$mirror_pid_file"

    return 1
  }

  stop_mirror() {
    [ -f "$mirror_pid_file" ] || return 0

    while IFS= read -r pid; do
      [ -n "$pid" ] || continue
      kill "$pid" 2>/dev/null || true
    done < "$mirror_pid_file"

    $rm -f "$mirror_pid_file"
  }

  apply_extend() {
    stop_mirror

    for output in "''${outputs[@]}"; do
      $niri msg output "$output" on || true
    done

    $sleep 0.2
    $niri msg action load-config-file || true
  }

  apply_mirror() {
    source_output="$1"
    stop_mirror

    for output in "''${outputs[@]}"; do
      $niri msg output "$output" on || true
    done

    $sleep 0.2
    $niri msg action load-config-file || true
    $mkdir -p "$state_dir"
    : > "$mirror_pid_file"

    for output in "''${outputs[@]}"; do
      if [ "$output" != "$source_output" ]; then
        $nohup "$wl_mirror" --fullscreen-output "$output" "$source_output" >/dev/null 2>&1 &
        printf '%s\n' "$!" >> "$mirror_pid_file"
      fi
    done

    $niri msg action focus-monitor "$source_output" || true
  }

  apply_single() {
    target="$1"
    stop_mirror

    $niri msg output "$target" on
    $sleep 0.2

    for output in "''${outputs[@]}"; do
      if [ "$output" != "$target" ]; then
        $niri msg output "$output" off || true
      fi
    done

    $niri msg action focus-monitor "$target" || true
  }

  if mirror_is_active; then
    apply_extend
  elif [ "''${#active_outputs[@]}" -gt 1 ]; then
    apply_single "$(first_single_target)"
  elif [ "''${#active_outputs[@]}" -eq 1 ]; then
    current_output="''${active_outputs[0]}"
    if next_output="$(next_single_target "$current_output")"; then
      apply_single "$next_output"
    else
      apply_mirror "$current_output"
    fi
  else
    apply_single "$(first_single_target)"
  fi
''
