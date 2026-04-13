{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dev.johnrinehart.agentTools;
in
{
  options.dev.johnrinehart.agentTools = {
    enable = lib.mkEnableOption "agent-oriented local AI tooling";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.agent-deck
      pkgs.codex-cli-nix
      pkgs.omx-agent-tools
      pkgs.oh-my-codex
    ];
  };
}
