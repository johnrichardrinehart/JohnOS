{ lib
, writeShellScriptBin
, libnotify
, systemd
, jq
}:

writeShellScriptBin "lock-vt-sessions" ''
  ${libnotify}/bin/notify-send -u normal 'Idle... locking (and killing all VT sessions)' && \
  sleep 3 && \
  ${systemd}/bin/loginctl kill-session $(${systemd}/bin/loginctl list-sessions --json=short | ${jq}/bin/jq -r 'map(select(.tty != "tty1" and .tty != null) | .session) | join(" ")') && \
  ${systemd}/bin/loginctl lock-session
''
