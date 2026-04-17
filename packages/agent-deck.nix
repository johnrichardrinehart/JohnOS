{
  lib,
  buildGo124Module,
  fetchFromGitHub,
  git,
}:
buildGo124Module rec {
  pname = "agent-deck";
  version = "unstable-2026-04-17";
  rev = "138dfbedac789fe1a3ea5d6147dd525a5411f22b";

  src = fetchFromGitHub {
    owner = "johnrichardrinehart";
    repo = "agent-deck";
    inherit rev;
    hash = "sha256-9qgWtjxooX2Chyy05/KZZhuvnAq+MZqEWqWSaSv3Bhg=";
  };

  vendorHash = "sha256-1aCd3tT5Oh+K7kLils2r3kX4YMkDCL3Eqoj5XJ9R8m0=";

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
