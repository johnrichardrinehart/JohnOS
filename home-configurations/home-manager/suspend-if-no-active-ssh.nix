{
  confirmSshActivityCommand ? "",
  writeShellScriptBin,
  libnotify,
  systemd,
}:

writeShellScriptBin "suspend-if-no-active-ssh" ''
  set -eu

  if [ -n "${confirmSshActivityCommand}" ]; then
    if ! ${confirmSshActivityCommand}; then
      ${libnotify}/bin/notify-send -u normal 'Suspend canceled because SSH activity was detected'
      exit 0
    fi
  fi

  ${systemd}/bin/systemctl suspend-then-hibernate
''
