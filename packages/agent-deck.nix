{
  lib,
  buildGoModule,
  fetchFromGitHub,
  git,
}:
buildGoModule rec {
  pname = "agent-deck";
  version = "0.20.1-1-g8a86b7b";

  src = fetchFromGitHub {
    owner = "asheshgoplani";
    repo = "agent-deck";
    rev = "a993c675cd751968c80891979ff7b5ced10ad8c0";
    hash = "sha256-/FnLFwwP/wX5t9PWWarQSg44bJhTLg8gtl1VK1LkusI=";
  };

  vendorHash = "sha256-hoVn3RTKhp0e48dPZlUQIPQygXA9Fi6hnJruaS53srQ=";

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
