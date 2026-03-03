{
  lib,
  buildGoModule,
  fetchFromGitHub,
  git,
}:
buildGoModule rec {
  pname = "agent-deck";
  version = "0.26.4";

  src = fetchFromGitHub {
    owner = "asheshgoplani";
    repo = "agent-deck";
    rev = "v${version}";
    hash = "sha256-XEZKuKN/M1z47Fam0xLqwbIe1Tir8CH3aHsNyQP0Tgs=";
  };

  vendorHash = "sha256-PrhxSMJm4TPRtNHkg36HQJE4a0UDfYUpQdYA0tUor9k=";

  subPackages = [ "cmd/agent-deck" ];

  nativeCheckInputs = [ git ];

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
