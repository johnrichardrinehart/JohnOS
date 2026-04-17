{
  lib,
  buildGo124Module,
  fetchFromGitHub,
  git,
}:
buildGo124Module rec {
  pname = "agent-deck";
  version = "unstable-2026-04-19";
  rev = "118bfc4d391c3eb052c3460982105bf761584ab0";

  src = fetchFromGitHub {
    owner = "johnrichardrinehart";
    repo = "agent-deck";
    inherit rev;
    hash = "sha256-FLN+GQQ05eB4AN15/mc1mlasT2gIIAVi/CWYJwDG+mA=";
  };

  vendorHash = "sha256-aH32Up3redCpeyjZkjcjiVN0tfYpF+GFB2WVAGm3J2I=";

  subPackages = [ "cmd/agent-deck" ];

  nativeCheckInputs = [ git ];
  checkFlags = [
    # This subprocess TUI smoke test depends on signal/log-flush behavior that
    # is not reliable in the Nix build sandbox. Keep the line-level wiring test
    # and the rest of the package tests enabled.
    "-skip=TestLogCgroupIsolationDecision_WiredIntoBootstrap/tui_startup_emits_line"
  ];

  preCheck = ''
    export HOME="$TMPDIR"
  '';

  meta = with lib; {
    description = "Your AI agent command center - manage multiple AI coding agents from one terminal";
    homepage = "https://github.com/johnrichardrinehart/agent-deck";
    license = licenses.mit;
    mainProgram = "agent-deck";
    maintainers = [ ];
  };
}
