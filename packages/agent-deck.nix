{
  lib,
  buildGo124Module,
  fetchFromGitHub,
  git,
}:
buildGo124Module rec {
  pname = "agent-deck";
  version = "unstable-2026-04-13";
  rev = "5b664d6b9be8cdb83289ac36d6b364172fefa7c1";

  src = fetchFromGitHub {
    owner = "johnrichardrinehart";
    repo = "agent-deck";
    inherit rev;
    hash = "sha256-jfI4cybE8wpvj1z3BzQiiKB3EiP8A7NF0GBXlT+oOps=";
  };

  vendorHash = "sha256-1aCd3tT5Oh+K7kLils2r3kX4YMkDCL3Eqoj5XJ9R8m0=";

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
