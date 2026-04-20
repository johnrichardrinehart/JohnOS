{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dev.johnrinehart.agentTools;
  codexSystemTopLevelConfig = ''
    # Managed by JohnOS. User and project Codex config layers may still override
    # these defaults when needed.

    sandbox_mode = "workspace-write"
  '';
  codexSandboxWorkspaceConfig = ''
    # codex-cli 0.120.x does not honor the newer `[permissions.<profile>]`
    # filesystem schema here; it expects the legacy workspace-write sandbox
    # settings instead.
    [sandbox_workspace_write]
    writable_roots = [
      "current_working_directory",
      "/nix/var/nix/daemon-socket",
    ]
    network_access = true
  '';
  codexSystemTopLevelFile = pkgs.writeText "codex-system-top-level.toml" codexSystemTopLevelConfig;
  codexSandboxWorkspaceFile = pkgs.writeText "codex-sandbox-workspace.toml" codexSandboxWorkspaceConfig;
  codexFromOmxSetup = pkgs.runCommand "codex-from-omx-setup" { outputs = [ "out" "hooks" ]; } ''
    export HOME="$TMPDIR/home"
    export CODEX_HOME="$HOME/.codex"

    mkdir -p "$HOME" "$TMPDIR/work"
    cd "$TMPDIR/work"

    ${lib.getExe pkgs.oh-my-codex} setup --scope user --force --verbose > "$TMPDIR/setup.log"
    ${lib.getExe pkgs.oh-my-codex} doctor > "$TMPDIR/doctor.log"

    if ! grep -Fq "[OK] Native hooks: hooks.json includes OMX-managed coverage for all native hook events" "$TMPDIR/doctor.log"; then
      cat "$TMPDIR/doctor.log" >&2
      exit 1
    fi

    cat ${codexSystemTopLevelFile} "$CODEX_HOME/config.toml" ${codexSandboxWorkspaceFile} > "$out"
    cp "$CODEX_HOME/hooks.json" "$hooks"
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
    environment.etc."codex/config.toml".source = codexFromOmxSetup;
    environment.etc."codex/hooks.json".source = codexFromOmxSetup.hooks;
  };
}
