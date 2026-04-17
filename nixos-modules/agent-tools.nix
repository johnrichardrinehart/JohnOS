{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dev.johnrinehart.agentTools;
  codexSystemConfig = ''
    # Managed by JohnOS. User and project Codex config layers may still override
    # these defaults when needed.
    #
    # codex-cli 0.120.x does not honor the newer `[permissions.<profile>]`
    # filesystem schema here; it expects the legacy workspace-write sandbox
    # settings instead.

    sandbox_mode = "workspace-write"

    [sandbox_workspace_write]
    writable_roots = [
      "current_working_directory",
      "/nix/var/nix/daemon-socket",
    ]
    network_access = true
  '';
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

    environment.etc."codex/config.toml".text = codexSystemConfig;
  };
}
