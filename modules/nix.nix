{ inputs, config, lib, ... }: let
cfg = config.dev.johnrinehart.nix;
in {
	options.dev.johnrinehart.nix = {
		enable = lib.mkEnableOption "reasonable Nix settings";

    trusted-users = lib.mkOption {
      default = builtins.attrNames (lib.filterAttrs (_: v: v.isNormalUser)  config.users.users) ++ [ "@wheel" ];
    };
	};

	config = lib.mkIf cfg.enable {
		nix = {
			registry = {
				nixpkgs.flake = inputs.nixpkgs;
			};

			nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];

			settings.experimental-features = [ "nix-command" "flakes" ];

			settings.trusted-users = cfg.trusted-users;
		};
	};
}
