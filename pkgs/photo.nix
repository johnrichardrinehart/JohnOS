{ pkgs, ... }:
pkgs.stdenv.mkDerivation rec {
  name = "ocean-photo";

  version = "1.0.0";

  infile = ./ocean.jpg;

  src = ./.;

  installPhase = ''
    mkdir -p "$out/bin";
    cp $src/ocean.jpg $out/bin/ocean.jpg
  '';

  meta = with pkgs.lib; {
    homepage = "https://johnrinehart.dev";
    description = "A derivation to store my background photo";
    platforms = platforms.linux;
  };
}
