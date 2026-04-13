{ lib, nix, writeShellApplication }:
writeShellApplication {
  name = "codex-cli-nix";
  runtimeInputs = [ nix ];
  text = ''
    exec nix run github:sadjow/codex-cli-nix -- "$@"
  '';

  meta = with lib; {
    description = "Shell wrapper that runs Codex via sadjow/codex-cli-nix";
    license = licenses.mit;
    mainProgram = "codex-cli-nix";
    maintainers = [ ];
    platforms = platforms.linux ++ platforms.darwin;
  };
}
