{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dev.johnrinehart.agentTools;
  mkMergedCodexConfig =
    {
      name,
      layers,
    }:
    pkgs.dev.johnrinehart.codex-config-merged.override {
      inherit name layers;
      header = codexMergedConfigHeader;
    };

  codexMergedConfigHeader = pkgs.writeText "codex-config-header.toml" ''
    # Managed by JohnOS. User and project Codex config layers may still override
    # these defaults when needed.
    #
    # Unix socket permissions are supported by codex-cli 0.130.0 via
    # openai/codex dd30c8eedd171d2dda71c43fac27dc42f457da5f (#15120).

  '';

  codexPluginTopLevelConfig = lib.optionalString (cfg.codexCli.statusLinePlugins != [ ]) ''
    [dev.johnrinehart.agentTools.codexCli]
    statusLinePlugins = ${builtins.toJSON cfg.codexCli.statusLinePlugins}
  '';

  codexSystemTopLevelConfig = ''
    # Managed by JohnOS. User and project Codex config layers may still override
    # these defaults when needed.

    sandbox_mode = "workspace-write"
    suppress_unstable_features_warning = true

    [tui]
    status_line = [
      "model-with-reasoning",
      "git-branch",
      "context-remaining",
      "total-input-tokens",
      "total-output-tokens",
      "weekly-limit",
    ]
  ''
  + codexPluginTopLevelConfig;

  codexPermissionsConfig = ''
    default_permissions = "johnos-workspace"

    [permissions.johnos-workspace.filesystem]
    ":root" = "read"
    ":project_roots" = "write"
    ":tmpdir" = "write"
    "/tmp" = "write"

    [permissions.johnos-workspace.network]
    enabled = true

    [permissions.johnos-workspace.network.unix_sockets]
    "/nix/var/nix/daemon-socket/socket" = "allow"
  '';
  codexSystemTopLevelFile = pkgs.writeText "codex-system-top-level.toml" codexSystemTopLevelConfig;
  codexPermissionsFile = pkgs.writeText "codex-permissions.toml" codexPermissionsConfig;
  codexMergedConfig = mkMergedCodexConfig {
    name = "codex-config-merged.toml";
    layers = [
      codexSystemTopLevelFile
    ]
    ++ cfg.codexCli.configLayers
    ++ [
      codexPermissionsFile
    ];
  };
in
{
  options.dev.johnrinehart.agentTools = {
    enable = lib.mkEnableOption "agent-oriented local AI tooling";

    "oh-my-codex".enable =
      lib.mkEnableOption "oh-my-codex multi-agent orchestration layer for Codex CLI";

    codexCli.statusLinePlugins = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      example = [ "codex-weekly-pace" ];
      description = ''
        Status-line plugin names to expose in the system Codex config layer.
        When this contains "codex-weekly-pace", the corresponding helper
        package is installed into systemPackages.
      '';
    };

    codexCli.configLayers = lib.mkOption {
      type = with lib.types; listOf path;
      default = [ ];
      description = ''
        Additional Codex config.toml layers to merge between the base system
        layer and sandbox layer. Submodules can publish configuration here.
      '';
    };

    codexCli.hooksSource = lib.mkOption {
      type = with lib.types; nullOr path;
      default = null;
      description = ''
        Optional hooks.json source published by a submodule.
      '';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      environment.systemPackages = [
        pkgs.dev.johnrinehart.agent-deck
        pkgs.dev.johnrinehart.claude-code-nix
        pkgs.dev.johnrinehart.codex-cli-nix
        pkgs.dev.johnrinehart.herdr
      ];

      # Always publish a system Codex config layer for agentTools-enabled hosts,
      # even when OMX is disabled.
      environment.etc."codex/config.toml".source = codexMergedConfig;
    })
    (lib.mkIf (cfg.enable && lib.elem "codex-weekly-pace" cfg.codexCli.statusLinePlugins) {
      environment.systemPackages = [ pkgs.dev.johnrinehart.codex-weekly-pace ];
    })
    (lib.mkIf cfg."oh-my-codex".enable (
      let
        codexOmxLayer = pkgs.dev.johnrinehart.codex-omx-layer;
      in
      {
        environment.systemPackages = [
          pkgs.dev.johnrinehart.oh-my-codex
          pkgs.dev.johnrinehart.omx-agent-tools
        ];

        dev.johnrinehart.agentTools.codexCli.configLayers = lib.mkAfter [ codexOmxLayer.config ];
        dev.johnrinehart.agentTools.codexCli.hooksSource = lib.mkDefault codexOmxLayer.hooks;

        # Codex discovers hooks.json next to each config.toml layer; keep OMX in
        # the immutable system layer so user/project hooks can coexist separately.
        environment.etc."codex/hooks.json".source = cfg.codexCli.hooksSource;
      }
    ))
    (lib.mkIf (cfg.enable && cfg.codexCli.hooksSource != null) {
      environment.etc."codex/hooks.json".source = cfg.codexCli.hooksSource;
    })
  ];
}
