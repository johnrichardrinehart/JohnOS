{
  pkgs ? import <nixpkgs> { },
}:
let
  name = "rock5c-flash-image";
  script = (pkgs.writeScriptBin name (builtins.readFile ./flash-image.sh)).overrideAttrs (old: {
    buildCommand = "${old.buildCommand}\npatchShebangs $out";
  });
  runtimeInputs = with pkgs; [
    bash
    coreutils
    e2fsprogs
    gawk
    gnugrep
    nix
    parted
    util-linux
  ];
  runtimePath = pkgs.lib.makeBinPath runtimeInputs;
in
pkgs.runCommand name {
  nativeBuildInputs = [ pkgs.makeWrapper ];
} ''
  mkdir -p "$out/bin"
  makeWrapper "${script}/bin/${name}" "$out/bin/${name}" --prefix PATH : "${runtimePath}"
''
