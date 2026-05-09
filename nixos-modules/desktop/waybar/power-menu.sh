#!/bin/sh

option() {
  printf '%s\t%s\t%s\n' "$1" "$2" "$3"
}

options() {
  option "Suspend" "weather-clear-night,weather-clear-night-symbolic" "systemctl suspend"
  option "Hibernate" "drive-harddisk-system,drive-harddisk-system-symbolic,drive-harddisk" "systemctl hibernate"
  option "Power off" "system-shutdown,system-shutdown-symbolic" "systemctl poweroff"
  option "Restart" "view-refresh,system-reboot,system-reboot-symbolic" "systemctl reboot"
}

tab=$(printf '\t')
option_count=$(options | wc -l | tr -d ' ')
[ "$option_count" -gt 0 ] || exit 0

choice=$(
  options |
    while IFS="$tab" read -r name icon action; do
      printf '%s\0icon\037%s\n' "$name" "$icon"
    done |
    fuzzel --dmenu --icon-theme=HighContrast --prompt "Power: " --width 24 --lines "$option_count" --minimal-lines
) || exit 0

action=$(
  options |
    while IFS="$tab" read -r name icon action; do
      [ "$name" = "$choice" ] || continue
      printf '%s\n' "$action"
      break
    done
)

[ -n "$action" ] || exit 0
exec sh -c "$action"
