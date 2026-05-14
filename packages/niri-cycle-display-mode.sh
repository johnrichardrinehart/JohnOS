#!/usr/bin/env bash
set -euo pipefail

command="${1:-cycle}"

state_dir="${XDG_RUNTIME_DIR:-/tmp}/johnos-niri-display-mode"
mirror_pid_file="$state_dir/wl-mirror.pids"
mirror_source_file="$state_dir/wl-mirror.source"
f9_picker_pid_file="$state_dir/f9-picker.pid"

is_internal_output() {
  case "$1" in
  eDP-* | LVDS-* | DSI-*) return 0 ;;
  *) return 1 ;;
  esac
}

load_outputs() {
  if ! outputs_json="$(niri msg --json outputs 2>/dev/null)"; then
    return 1
  fi

  mapfile -t outputs < <(jq -r 'to_entries | map(.value.name // .key) | sort | .[]' <<<"$outputs_json")
  mapfile -t active_outputs < <(jq -r 'to_entries[] | select(.value.logical != null) | .value.name // .key' <<<"$outputs_json")

  single_outputs=()
  internal_outputs=()
  external_outputs=()

  for output in "${outputs[@]}"; do
    if is_internal_output "$output"; then
      internal_outputs+=("$output")
    else
      external_outputs+=("$output")
      single_outputs+=("$output")
    fi
  done
  for output in "${internal_outputs[@]}"; do
    single_outputs+=("$output")
  done
}

first_single_target() {
  printf '%s\n' "${single_outputs[0]}"
}

next_single_target() {
  current="$1"

  for i in "${!single_outputs[@]}"; do
    if [ "${single_outputs[$i]}" = "$current" ]; then
      next_index=$((i + 1))
      if [ "$next_index" -lt "${#single_outputs[@]}" ]; then
        printf '%s\n' "${single_outputs[$next_index]}"
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
  done <"$mirror_pid_file"

  return 1
}

stop_mirror() {
  [ -f "$mirror_pid_file" ] || return 0

  while IFS= read -r pid; do
    [ -n "$pid" ] || continue
    kill "$pid" 2>/dev/null || true
  done <"$mirror_pid_file"

  rm -f "$mirror_pid_file" "$mirror_source_file"
}

apply_extend() {
  stop_mirror

  [ "${#outputs[@]}" -gt 0 ] || return 0

  for output in "${outputs[@]}"; do
    niri msg output "$output" on || true
  done

  sleep 0.2
  niri msg action load-config-file || true
}

apply_mirror() {
  source_output="$1"
  stop_mirror

  [ "${#outputs[@]}" -gt 1 ] || return 0

  for output in "${outputs[@]}"; do
    niri msg output "$output" on || true
  done

  sleep 0.2
  niri msg action load-config-file || true
  mkdir -p "$state_dir"
  : >"$mirror_pid_file"
  printf '%s\n' "$source_output" >"$mirror_source_file"

  for output in "${outputs[@]}"; do
    if [ "$output" != "$source_output" ]; then
      nohup wl-mirror --fullscreen-output "$output" "$source_output" >/dev/null 2>&1 &
      printf '%s\n' "$!" >>"$mirror_pid_file"
    fi
  done

  niri msg action focus-monitor "$source_output" || true
}

apply_single() {
  target="$1"
  stop_mirror

  niri msg output "$target" on
  sleep 0.2

  for output in "${outputs[@]}"; do
    if [ "$output" != "$target" ]; then
      niri msg output "$output" off || true
    fi
  done

  niri msg action focus-monitor "$target" || true
}

output_is_active() {
  candidate="$1"

  for output in "${active_outputs[@]}"; do
    if [ "$output" = "$candidate" ]; then
      return 0
    fi
  done

  return 1
}

ensure_internal_when_alone() {
  load_outputs || return 0
  [ "${#internal_outputs[@]}" -gt 0 ] || return 0
  [ "${#external_outputs[@]}" -eq 0 ] || return 0

  internal_output="${internal_outputs[0]}"
  output_is_active "$internal_output" && return 0

  apply_single "$internal_output"
}

focused_output() {
  niri msg --json focused-output 2>/dev/null | jq -r '.name // empty'
}

json_status() {
  text="$1"
  class="$2"

  jq -cn --arg text "$text" --arg class "$class" \
    '{text: $text, tooltip: $text, class: $class}'
}

display_status() {
  load_outputs || exit 1
  [ "${#outputs[@]}" -gt 1 ] || exit 1

  if mirror_is_active; then
    json_status "mirror" "mirror"
    exit 0
  fi

  current_output="$(focused_output || true)"
  if [ -z "$current_output" ] || ! output_is_active "$current_output"; then
    current_output="${active_outputs[0]:-}"
  fi

  if [ -z "$current_output" ]; then
    json_status "(no output)" "unknown"
  elif [ "${#active_outputs[@]}" -gt 1 ]; then
    json_status "$current_output (extend)" "extend"
  else
    json_status "$current_output (single)" "single"
  fi
}

current_mirror_source() {
  local source_output

  if [ -f "$mirror_source_file" ] && IFS= read -r source_output <"$mirror_source_file"; then
    if [ -n "$source_output" ] && output_is_active "$source_output"; then
      printf '%s\n' "$source_output"
      return 0
    fi
  fi

  focused_output
}

picker_is_active() {
  [ -f "$f9_picker_pid_file" ] || return 1

  if IFS= read -r pid <"$f9_picker_pid_file"; then
    [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && return 0
  fi

  rm -f "$f9_picker_pid_file"
  return 1
}

display_picker() {
  picker_is_active && return 0

  load_outputs || exit 0
  [ "${#outputs[@]}" -gt 1 ] || exit 0

  if mirror_is_active; then
    source_output="$(current_mirror_source || true)"
    if [ -n "$source_output" ] && output_is_active "$source_output"; then
      niri msg action focus-monitor "$source_output" || true
      sleep 0.1
    fi
  fi

  mkdir -p "$state_dir"
  printf '%s\n' "$$" >"$f9_picker_pid_file"
  trap 'rm -f "$f9_picker_pid_file"' EXIT

  menu="Extend"
  for output in "${outputs[@]}"; do
    menu="$menu
  Single: $output"
  done
  menu="$menu
  Mirror"

  selection=$(printf '%s\n' "$menu" | fuzzel --dmenu --prompt "Display: ") || exit 0

  case "$selection" in
  Extend)
    apply_extend
    ;;
  "Single: "*)
    apply_single "${selection#Single: }"
    ;;
  Mirror)
    source_output="$(focused_output || true)"
    if [ -z "$source_output" ] || ! output_is_active "$source_output"; then
      source_output="${active_outputs[0]:-$(first_single_target)}"
    fi
    apply_mirror "$source_output"
    ;;
  esac
}

watch_outputs() {
  while true; do
    ensure_internal_when_alone
    sleep 2
  done
}

cycle_display_mode() {
  load_outputs || exit 0
  [ "${#outputs[@]}" -gt 0 ] || exit 0

  if mirror_is_active; then
    apply_extend
  elif [ "${#outputs[@]}" -eq 1 ]; then
    if [ "${#active_outputs[@]}" -eq 0 ]; then
      apply_single "$(first_single_target)"
    fi
  elif [ "${#active_outputs[@]}" -gt 1 ]; then
    apply_single "$(first_single_target)"
  elif [ "${#active_outputs[@]}" -eq 1 ]; then
    current_output="${active_outputs[0]}"
    if next_output="$(next_single_target "$current_output")"; then
      apply_single "$next_output"
    else
      apply_mirror "$current_output"
    fi
  else
    apply_single "$(first_single_target)"
  fi
}

case "$command" in
pick) display_picker ;;
status) display_status ;;
--watch) watch_outputs ;;
cycle) cycle_display_mode ;;
*)
  echo "Usage: niri-cycle-display-mode [pick|status|--watch|cycle]" >&2
  exit 2
  ;;
esac
