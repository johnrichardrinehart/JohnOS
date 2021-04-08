# build an ISO image that will auto install NixOS and reboot
# $ nix-build make-iso.nix
{
users ? {
  test = {
    password = "testy";
    isNormalUser = true;
  };
}, ...}:
(import <nixpkgs/nixos/lib/eval-config.nix> {
	system = builtins.currentSystem;
	modules = [
		<nixpkgs/nixos/modules/installer/cd-dvd/iso-image.nix>
		./iso.nix
		./ssh.nix
		./networking.nix
		(import ./display.nix {autologinUser=(builtins.head (builtins.attrNames users));})
		(import ./users.nix {users = users;})
		./packages.nix
	];
}).config.system.build.isoImage
