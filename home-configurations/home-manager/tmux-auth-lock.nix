{
  bash,
  coreutils,
  shadow,
  writeShellScriptBin,
}:

writeShellScriptBin "tmux-auth-lock" ''
  set -eu

  user_name=$(${coreutils}/bin/id -un)

  while ! ${shadow}/bin/su -s ${bash}/bin/sh "$user_name" -c true; do
    ${coreutils}/bin/printf '\nAuthentication failed. Try again.\n' >&2
  done

  ${coreutils}/bin/clear
''
