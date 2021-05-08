with (import <nixpkgs> {});
let
  imports = let agenixCommit = "204bd95"; in {
	agenix = (callPackage "${builtins.fetchTarball {
		url = "https://github.com/ryantm/agenix/archive/${agenixCommit}.tar.gz";
		sha256 = "0xpfq3mnpnj7ygl4yphm8mvlhbx5a87p0nh3cjgnd2v1l4m0044g";
	}}" {}).agenix;
  };
in
mkShell {
  buildInput = [
	imports.agenix
  ];
}
