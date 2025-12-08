{ stdenv
, lib
, makeWrapper
, niri
, jq
, fuzzel
, coreutils
, gnugrep
}:

let
  buildInputs = [ niri jq fuzzel coreutils gnugrep ];
in
stdenv.mkDerivation {
  pname = "fuzzel_dmenu";
  version = "0.1.0";

  src = ./fuzzel_dmenu.sh;

  inherit buildInputs;
  nativeBuildInputs = [ makeWrapper ];

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    mkdir -p $out/bin
    cp $src $out/bin/fuzzel_dmenu
    chmod +x $out/bin/fuzzel_dmenu
    patchShebangs $out/bin/fuzzel_dmenu
    wrapProgram $out/bin/fuzzel_dmenu --prefix PATH : ${lib.makeBinPath buildInputs}
  '';

  meta = with lib; {
    description = "Fuzzel dmenu script for niri window manager";
    license = licenses.mit;  # Adjust according to your license
    platforms = platforms.all;
    mainProgram = "fuzzel_dmenu";
  };
}
