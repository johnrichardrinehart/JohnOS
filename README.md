# What?
This is a repo that contains a set of Nix expressions used to build a custom 
Nix operating system that can be booted from a flash drive in the spirit of
[erasing my darlings](https://grahamc.com/blog/erase-your-darlings).

# Where?
Uhh, here.

# When?

Check the commit history.

# Why?
Why not?

But, seriously, I have a dream to be able to share development operating systems
within projects and to be completely independent of any host OS installed to the 
hard disk of any machine that I own. This project allows me to recover from a 
hardware failure with "zero downtime" (TM).

# How?
Easy. Get `nix` installed on some machine (or install NixOS which comes with `nix`
package manager. 

1. `nix-build` at the root of this repository.

or (if you want to customize user(s)) then run

1. `nix-build --arg users "import ./custom-users.nix"`

2. `cat ./result/iso/johnos.iso > /dev/sdb` (or use another tool to write the ISO to a flash drive)

where `./custom-users.nix` is a file that you will write and looks something like

```
let
	pkgs = (import <nixpkgs> {});
in
{
	# change the key name below to change the user name from `acoolusername` to
	# whatever you want
	acoolusername = {
		password="super-secret-password";
		isNormalUser=true; # allow to log in
		extraGroups = ["wheel" "foo" "bar"];
		# find more packages at https://search.nixos.org/packages
		packages = with pkgs; [
			git	
			brave
			htop
			vscodium
			discord
		];
	};
}
```

# Notes
1. The user defined first in this `nix` configuration will be automatically logged in

# Further goals
- [ ] Support declarative secrets
- [ ] Encrypt `/` using LUKS
- [ ] Start using home-manager
