# build an ISO image that will auto install NixOS and reboot
# $ nix-build make-iso.nix
{
users ?{
  test = {
    password = "testy";
    isNormalUser = true;
  };
}, system }:
let
config = (import <nixpkgs/nixos/lib/eval-config.nix> {
	system = system; 
	modules = [
		./iso.nix
		./ssh.nix
		./networking.nix
		(import ./display.nix {autologinUser=(builtins.head (builtins.attrNames users));})
		(import ./users.nix {users = users;})
		./sound.nix
		./packages.nix
		./peripherals.nix
	];
}).config;

in rec {
iso = config.system.build.isoImage;
}
