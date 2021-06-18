{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/master";
      flake = true;
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # agenix implementation borrowed from https://github.com/pimeys/system-flake
    agenix.url = "github:ryantm/agenix";
  };

  outputs = inputs:
    let
      home-manager-config = {
        config = {
          home-manager = {
            useUserPackages = true;
            users.john = ./users/john.nix;
            users.ardan = ./users/ardan.nix;
          };
        };
      };

      rpiPackages = (import inputs.nixpkgs) {
        localSystem = "x86_64-linux";
        crossSystem = {
          config = "aarch64-unknown-linux-gnu";
        };
      };

    in

    rec {
      nixosConfigurations = {
        # vbox_config is designed to be used within a pre-existing NixOS installation as
        # `nixos-rebuild switch --flake .#vbox-config` # default package is this flake
        vbox-config = with inputs.nixpkgs; lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./hardware-configuration.nix
            ./virtualbox.nix
            ./configuration.nix
            ./agenix.nix
            inputs.agenix.nixosModules.age
            inputs.home-manager.nixosModules.home-manager
            home-manager-config
          ];
          specialArgs = { inherit (inputs) nixpkgs agenix; };
        };

        flash-drive-iso = with inputs.nixpkgs; lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./configuration.nix
            ./agenix.nix
            inputs.agenix.nixosModules.age
            inputs.home-manager.nixosModules.home-manager
            home-manager-config
            "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/iso-image.nix"
          ];
          specialArgs = { inherit (inputs) nixpkgs agenix; };
        };


        rpi-sdcard = inputs.nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          modules = [
            ./configuration.nix
            (import "${inputs.nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix")
          ];
          specialArgs = { inherit (inputs) agenix; nixpkgs = rpiPackages; };
        };
      };

      packages.x86_64-linux = {
        flash-drive-iso = nixosConfigurations.flash-drive-iso.config.system.build.isoImage;
      };

      defaultPackage.x86_64-linux = packages.x86_64-linux.flash-drive-iso;

    };

}
