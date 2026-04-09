{
  writeShellScriptBin,
  libnotify,
  systemd,
  jq,
  coreutils,
  gawk,
  idleTimeoutSeconds,
}:

writeShellScriptBin "suspend-if-no-active-ssh" ''
  set -eu

  idle_timeout=${toString idleTimeoutSeconds}
  did_notify=0

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
    idle_field=$(${coreutils}/bin/who -u | ${gawk}/bin/awk -v tty_name="$tty_name" '$2 == tty_name { print $5; found=1; exit } END { if (!found) print "old" }')
    idle_to_seconds "$idle_field"
  }

  has_active_ssh_session() {
    while IFS=$'\t' read -r session_id tty_name; do
      [ -n "$session_id" ] || continue
      [ -n "$tty_name" ] || continue

      idle_seconds=$(session_idle_seconds "$tty_name")
      if [ "$idle_seconds" -lt "$idle_timeout" ]; then
        return 0
      fi
    done <<EOF
$(${systemd}/bin/loginctl list-sessions --json=short | ${jq}/bin/jq -r '
  map(
    select(.tty != null and (.tty | test("^pts/[0-9]+$"))) | [.session, .tty] | @tsv
  ) | .[]
')
EOF

    return 1
  }

  while has_active_ssh_session; do
    if [ "$did_notify" -eq 0 ]; then
      ${libnotify}/bin/notify-send -u normal 'Suspend deferred while SSH session is active'
      did_notify=1
    fi

    sleep 15
  done

  ${systemd}/bin/systemctl suspend-then-hibernate
''
