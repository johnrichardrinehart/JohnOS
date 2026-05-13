{ lib, stdenvNoCC }:

stdenvNoCC.mkDerivation {
  pname = "codex-weekly-pace";
  version = "0.1.0";

  src = ./codex-weekly-pace.sh;
  dontUnpack = true;

  installPhase = ''
    install -Dm755 "$src" "$out/bin/codex-weekly-pace"
  '';

  meta = with lib; {
    description = "Codex weekly limit over/under pace indicator with catch-up ETA scenarios";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "codex-weekly-pace";
    platforms = platforms.linux ++ platforms.darwin;
  };
}
