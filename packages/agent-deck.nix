{
  lib,
  buildGo126Module,
  fetchFromGitHub,
  git,
  tmux,
}:
buildGo126Module rec {
  pname = "agent-deck";
  version = "1.9.43";

  src = fetchFromGitHub {
    owner = "asheshgoplani";
    repo = "agent-deck";
    rev = "v${version}";
    hash = "sha256-6squ1J7t6/OHBBaLnxWN9gd1AqKdj5Rln4ViM9UsDbs=";
  };

  vendorHash = "sha256-1YV8u505VY2XZ+SzIR3zX563pHmcxYJUxeSreK3glv4=";

  subPackages = [ "cmd/agent-deck" ];

  nativeCheckInputs = [
    git
    tmux
  ];
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
    homepage = "https://github.com/asheshgoplani/agent-deck";
    license = licenses.mit;
    mainProgram = "agent-deck";
    maintainers = [ ];
  };
}
