{
  lib,
  buildGo124Module,
  fetchFromGitHub,
  git,
}:
buildGo124Module rec {
  pname = "agent-deck";
  version = "0.27.4";

  src = fetchFromGitHub {
    owner = "asheshgoplani";
    repo = "agent-deck";
    rev = "v${version}";
    hash = "sha256-oeR9QT+l6KaC92dnw1mww7X2Vv6pIJ9sK7IWeTb5sCY=";
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
