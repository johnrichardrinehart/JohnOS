{
  lib,
  buildGo124Module,
  fetchFromGitHub,
  git,
}:
buildGo124Module rec {
  pname = "agent-deck";
  version = "1.9.11";

  src = fetchFromGitHub {
    owner = "asheshgoplani";
    repo = "agent-deck";
    rev = "v${version}";
    hash = "sha256-u4MLitpKWg+KYQAOaFUUfzbc83aM4/HnkD+gBVqgfvk=";
  };

  vendorHash = "sha256-/7hzCID4Vu9z6VHN7NiAjyoZPEBPHet4fJdh/VSZaGQ=";

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
    homepage = "https://github.com/asheshgoplani/agent-deck";
    license = licenses.mit;
    mainProgram = "agent-deck";
    maintainers = [ ];
  };
}
