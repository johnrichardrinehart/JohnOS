# build an ISO image that will auto install NixOS and reboot
# $ nix-build make-iso.nix
{
users ?{
  test = {
    password = "testy";
    isNormalUser = true;
  };
}, lib}:
let
config = (import lib.eval-config.nix {
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
