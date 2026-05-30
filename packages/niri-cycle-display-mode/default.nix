{
  lib,
  coreutils,
  fuzzel,
  gnome-icon-theme,
  jq,
  libnotify,
  makeWrapper,
  niri,
  symlinkJoin,
  wl-mirror,
  writeScriptBin,
}:
let
  pname = "niri-cycle-display-mode";
  scriptSource =
    builtins.replaceStrings
      [ "@display_icon@" ]
      [ "${gnome-icon-theme}/share/icons/gnome/48x48/devices/video-display.png" ]
      (builtins.readFile ./niri-cycle-display-mode.sh);
  script = (writeScriptBin pname scriptSource).overrideAttrs (old: {
    buildCommand = "${old.buildCommand}\npatchShebangs $out";
  });
  runtimeInputs = [
    coreutils
    fuzzel
    jq
    libnotify
    niri
    wl-mirror
  ];
in
symlinkJoin {
  name = pname;
  paths = [ script ] ++ runtimeInputs;
  buildInputs = [ makeWrapper ];
  postBuild = "wrapProgram $out/bin/${pname} --prefix PATH : $out/bin";

  meta = {
    description = "Cycle and repair niri display modes";
    license = lib.licenses.mit;
    mainProgram = pname;
    maintainers = [ ];
    platforms = lib.platforms.linux;
  };
}
