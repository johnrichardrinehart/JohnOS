{
  coreutils,
  gawk,
  idleTimeoutSeconds,
  jq,
  systemd,
  terminalMultiplexer,
  tmux,
  writeShellScriptBin,
}:

writeShellScriptBin "lock-idle-ssh-sessions" ''
  set -eu

  idle_timeout=${toString idleTimeoutSeconds}
  terminal_multiplexer="${terminalMultiplexer}"

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

  lock_tmux_client_for_tty() {
    local tty_name=$1
    local tty_path="/dev/$tty_name"
    local client_tty

    ${tmux}/bin/tmux list-clients -F '#{client_tty}' 2>/dev/null | while IFS= read -r client_tty; do
      [ "$client_tty" = "$tty_path" ] || continue
      ${tmux}/bin/tmux lock-client -t "$client_tty" || true
    done
  }

  [ "$terminal_multiplexer" != "none" ] || exit 0

  while IFS=$'\t' read -r _session_id tty_name; do
    [ -n "$tty_name" ] || continue

    idle_seconds=$(session_idle_seconds "$tty_name")
    if [ "$idle_seconds" -lt "$idle_timeout" ]; then
      continue
    fi

    case "$terminal_multiplexer" in
      tmux)
        lock_tmux_client_for_tty "$tty_name"
        ;;
    esac
  done <<EOF
$(${systemd}/bin/loginctl list-sessions --json=short | ${jq}/bin/jq -r '
  map(
    select(.tty != null and (.tty | test("^pts/[0-9]+$"))) | [.session, .tty] | @tsv
  ) | .[]
')
EOF
''
