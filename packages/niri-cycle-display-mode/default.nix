{
  lib,
  coreutils,
  fuzzel,
  jq,
  makeWrapper,
  niri,
  symlinkJoin,
  wl-mirror,
  writeScriptBin,
}:
let
  pname = "niri-cycle-display-mode";
  script =
    (writeScriptBin pname (builtins.readFile ./niri-cycle-display-mode.sh)).overrideAttrs
      (old: {
        buildCommand = "${old.buildCommand}\npatchShebangs $out";
      });
  runtimeInputs = [
    coreutils
    fuzzel
    jq
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
