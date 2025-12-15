{ lib
, writeShellScriptBin
, libnotify
, systemd
, jq
}:

writeShellScriptBin "on-idle" ''
  ${libnotify}/bin/notify-send -u normal 'Idle... locking (and killing all VT sessions)' && \
  sleep 5 && \
  ${systemd}/bin/loginctl lock-session && \
  ${systemd}/bin/loginctl kill-session $(${systemd}/bin/loginctl list-sessions --json=short | ${jq}/bin/jq -r 'map(select(.tty != "tty1" and .tty != null) | .session) | join(" ")')
''
