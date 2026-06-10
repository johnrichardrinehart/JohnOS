{
  lib,
  nix,
  writeShellApplication,
}:
writeShellApplication {
  name = "claude-code-nix";
  runtimeInputs = [ nix ];
  text = ''
    exec nix run github:sadjow/claude-code-nix -- "$@"
  '';

  meta = with lib; {
    description = "Shell wrapper that runs Claude Code via sadjow/claude-code-nix";
    license = licenses.mit;
    mainProgram = "claude-code-nix";
    maintainers = [ ];
    platforms = platforms.linux ++ platforms.darwin;
  };
}
