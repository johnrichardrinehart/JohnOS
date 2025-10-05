{
  lib,
  writeShellScriptBin,
  feh,
  xorg,
  networkmanagerapplet,
  ...
}:
writeShellScriptBin "xsession" ''
  ${lib.getExe feh} --bg-fill ${../../static/ocean.jpg} # configure background
  ${xorg.xsetroot}/bin/xsetroot -cursor_name left_ptr # configure pointer
  ${lib.getExe networkmanagerapplet} --sm-disable --indicator &
''
