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
  codexHooksFromOmxSetup = pkgs.runCommand "codex-hooks-from-omx-setup" { } ''
    export HOME="$TMPDIR/home"
    export CODEX_HOME="$HOME/.codex"

    mkdir -p "$HOME" "$TMPDIR/work" "$out"
    cd "$TMPDIR/work"

    ${lib.getExe pkgs.oh-my-codex} setup --scope user --force --verbose > "$out/setup.log"
    ${lib.getExe pkgs.oh-my-codex} doctor > "$out/doctor.log"

    if ! grep -Fq "[OK] Native hooks: hooks.json includes OMX-managed coverage for all native hook events" "$out/doctor.log"; then
      cat "$out/doctor.log" >&2
      exit 1
    fi

    cp "$CODEX_HOME/hooks.json" "$out/hooks.json"
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

    # Codex discovers hooks.json next to each config.toml layer; keep OMX in
    # the immutable system layer so user/project hooks can coexist separately.
    environment.etc."codex/config.toml".text = codexSystemConfig;
    environment.etc."codex/hooks.json".source = "${codexHooksFromOmxSetup}/hooks.json";
  };
}
