{
  lib,
  buildGo124Module,
  fetchFromGitHub,
  git,
}:
buildGo124Module rec {
  pname = "agent-deck";
  version = "unstable-2026-03-29";
  rev = "56a6abaa18d273056234c55205d7459906afaff7";

  src = fetchFromGitHub {
    owner = "johnrichardrinehart";
    repo = "agent-deck";
    inherit rev;
    hash = "sha256-MRQwQdPg0NjgvtgkjWHcV5MNv5OZq9/Jpxc0ONIxZB8=";
  };

  vendorHash = "sha256-PrhxSMJm4TPRtNHkg36HQJE4a0UDfYUpQdYA0tUor9k=";

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
