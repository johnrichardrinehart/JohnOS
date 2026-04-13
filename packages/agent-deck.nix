{
  lib,
  buildGo124Module,
  fetchFromGitHub,
  git,
}:
buildGo124Module rec {
  pname = "agent-deck";
  version = "unstable-2026-04-12";
  rev = "ad55249fd8f6e6d5381c1f02db0aaf11b461f25c";

  src = fetchFromGitHub {
    owner = "johnrichardrinehart";
    repo = "agent-deck";
    inherit rev;
    hash = "sha256-/Rch+vmVFulJjR6ihWjqHAr8A/+1iBfgf6ldV2e5+Dg=";
  };

  vendorHash = "sha256-8PaCkPkmLXBz6UZeLTCeG3h/GGe9I15sOyxYmXiY31A=";

  subPackages = [ "cmd/agent-deck" ];

  nativeCheckInputs = [ git ];

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
