{
  lib,
  writeShellScriptBin,
  libnotify,
  systemd,
  jq,
  coreutils,
  gawk,
  idleTimeoutSeconds,
}:

writeShellScriptBin "on-idle" ''
    idle_timeout=${toString idleTimeoutSeconds}

    idle_to_seconds() {
      case "$1" in
        ""|".")
          echo 0
          ;;
        old)
          echo $((idle_timeout + 1))
          ;;
        *:*)
          IFS=: read -r hours minutes <<EOF
  $1
  EOF
          echo $((10#$hours * 3600 + 10#$minutes * 60))
          ;;
        *)
          echo $((10#$1 * 60))
          ;;
      esac
    }

    session_idle_seconds() {
      local tty_name=$1
      local idle_field
      idle_field=$(${coreutils}/bin/who -u | ${gawk}/bin/awk -v tty_name="$tty_name" '$2 == tty_name { print $5; exit }')
      idle_to_seconds "$idle_field"
    }

    ${libnotify}/bin/notify-send -u normal 'Idle... locking and pruning inactive VT/SSH sessions'
    sleep 5
    ${systemd}/bin/loginctl lock-session

    while IFS=$'\t' read -r session_id tty_name; do
      [ -n "$session_id" ] || continue
      [ -n "$tty_name" ] || continue

      idle_seconds=$(session_idle_seconds "$tty_name")
      if [ "$idle_seconds" -lt "$idle_timeout" ]; then
        continue
      fi

      ${systemd}/bin/loginctl kill-session "$session_id"
    done <<EOF
  $(${systemd}/bin/loginctl list-sessions --json=short | ${jq}/bin/jq -r '
    map(
      select(
        .tty != null and (
          ((.tty | test("^tty[0-9]+$")) and .tty != "tty1") or
          (.tty | test("^pts/[0-9]+$"))
        )
      ) | [.session, .tty] | @tsv
    ) | .[]
  ')
  EOF
''
