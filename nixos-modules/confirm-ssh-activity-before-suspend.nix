{
  coreutils,
  gawk,
  jq,
  promptTimeoutSeconds,
  systemd,
  writeShellScriptBin,
}:

writeShellScriptBin "confirm-ssh-activity-before-suspend" ''
  set -eu

  prompt_timeout=${toString promptTimeoutSeconds}
  poll_interval=15
  tmpdir=$(${coreutils}/bin/mktemp -d)
  previous_snapshot="$tmpdir/previous"
  current_snapshot="$tmpdir/current"

  cleanup() {
    ${coreutils}/bin/rm -rf "$tmpdir"
  }

  trap cleanup EXIT INT TERM HUP

  list_ssh_ttys() {
    ${systemd}/bin/loginctl list-sessions --json=short | ${jq}/bin/jq -r '
      map(
        select(.tty != null and (.tty | test("^pts/[0-9]+$"))) | .tty
      ) | .[]
    '
  }

  idle_to_seconds() {
    case "$1" in
      ""|".")
        echo 0
        ;;
      old)
        echo $((prompt_timeout + 1))
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

  snapshot_sessions() {
    local tty_name
    list_ssh_ttys | while IFS= read -r tty_name; do
      [ -n "$tty_name" ] || continue
      ${coreutils}/bin/printf '%s\t%s\n' "$tty_name" "$(session_idle_seconds "$tty_name")"
    done
  }

  write_tty_message() {
    local tty_name=$1
    local message=$2
    local tty_path="/dev/$tty_name"

    [ -w "$tty_path" ] || return 0
    ${coreutils}/bin/printf '\r\n[system] %s\r\n' "$message" >"$tty_path" || true
  }

  write_message_to_snapshot() {
    local snapshot_file=$1
    local message=$2
    local tty_name

    while IFS=$'\t' read -r tty_name _idle_seconds; do
      [ -n "$tty_name" ] || continue
      write_tty_message "$tty_name" "$message"
    done < "$snapshot_file"
  }

  activity_detected() {
    local previous_file=$1
    local current_file=$2
    local tty_name idle_seconds previous_idle

    while IFS=$'\t' read -r tty_name idle_seconds; do
      [ -n "$tty_name" ] || continue

      previous_idle=$(${gawk}/bin/awk -F '\t' -v tty_name="$tty_name" '
        $1 == tty_name { print $2; found=1; exit }
        END { if (!found) print "missing" }
      ' "$previous_file")

      if [ "$previous_idle" = "missing" ] || [ "$idle_seconds" -lt "$previous_idle" ]; then
        return 0
      fi
    done < "$current_file"

    return 1
  }

  snapshot_sessions > "$previous_snapshot"
  if [ ! -s "$previous_snapshot" ]; then
    exit 0
  fi

  write_message_to_snapshot "$previous_snapshot" "Suspend pending. Press Enter or type within $((prompt_timeout / 60)) minutes to keep this SSH session active."

  deadline=$(( $(${coreutils}/bin/date +%s) + prompt_timeout ))

  while [ "$(${coreutils}/bin/date +%s)" -lt "$deadline" ]; do
    ${coreutils}/bin/sleep "$poll_interval"
    snapshot_sessions > "$current_snapshot"

    if [ ! -s "$current_snapshot" ]; then
      exit 0
    fi

    if activity_detected "$previous_snapshot" "$current_snapshot"; then
      write_message_to_snapshot "$current_snapshot" "Suspend canceled because SSH activity was detected."
      exit 1
    fi

    ${coreutils}/bin/mv "$current_snapshot" "$previous_snapshot"
  done

  write_message_to_snapshot "$previous_snapshot" "No SSH activity detected. Suspending now."
  exit 0
''
