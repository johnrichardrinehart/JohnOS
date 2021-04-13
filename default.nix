# build an ISO image that will auto install NixOS and reboot
# $ nix-build make-iso.nix
{
users ?{
  test = {
    password = "testy";
    isNormalUser = true;
  };
}, ...}:
let
config = (import <nixpkgs/nixos/lib/eval-config.nix> {
	system = builtins.currentSystem;
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
build = config.system.build.isoImage;
}
