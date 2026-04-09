{
  lib,
  buildGo124Module,
  fetchFromGitHub,
  git,
}:
buildGo124Module rec {
  pname = "agent-deck";
  version = "unstable-2026-04-09";
  rev = "a541040fd917f83e2f01f0625da3bcb9226e78f7";

  src = fetchFromGitHub {
    owner = "johnrichardrinehart";
    repo = "agent-deck";
    inherit rev;
    hash = "sha256-CiIE3iU0SelmNQm756sO5cSJrjDi/Xu7/Tl7C25fz3U=";
  };

  vendorHash = "sha256-qKK9Wu5+0bi+x6/OwRueIvPi6f4hFUqG+RkhWnLOr5Q=";

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
