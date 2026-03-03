{
  lib,
  buildGoModule,
  fetchFromGitHub,
  git,
}:
buildGoModule rec {
  pname = "agent-deck";
  version = "0.25.1";

  src = fetchFromGitHub {
    owner = "asheshgoplani";
    repo = "agent-deck";
    rev = "13671213424e674bf92bd210203bc963c62c38ab";
    hash = "sha256-q2wMVkpAt9SjkmECmS5dIkOZTEkabsw884WtxJSlv3Q=";
  };

  vendorHash = "sha256-eJtqqSK8UYa6V/NroJzNvXzhEaabiKJSF6/fitSr5LE=";

  subPackages = [ "cmd/agent-deck" ];

  nativeCheckInputs = [ git ];

  meta = with lib; {
    description = "Your AI agent command center - manage multiple AI coding agents from one terminal";
    homepage = "https://github.com/asheshgoplani/agent-deck";
    license = licenses.mit;
    mainProgram = "agent-deck";
    maintainers = [ ];
  };
}
