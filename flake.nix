{
  inputs = {
    rpinixpkgs.url = "github:samueldr/nixpkgs/wip/armv7lfixes"; # from NixOS Discord
    nixpkgs_release-2009.url = "github:NixOS/nixpkgs/release-20.09";
    nixpkgs_release-2105.url = "github:NixOS/nixpkgs/release-21.05";
    nixpkgs_unstable.url = "github:NixOS/nixpkgs/nixos-unstable";


    home-manager = {
      url = "github:nix-community/home-manager/release-21.05";
      flake = true;
      inputs.nixpkgs.follows = "nixpkgs_release-2105";
    };

    # agenix implementation borrowed from https://github.com/pimeys/system-flake
    agenix.url = "github:ryantm/agenix";
  };

  outputs = inputs:
    let
      nixpkgs = inputs.nixpkgs_release-2105;
      nixpkgs-unstable = inputs.nixpkgs_unstable;

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
        nixos = nixosConfigurations.vbox-config;

        # vbox_config is designed to be used within a pre-existing NixOS installation as
        # `nixos-rebuild switch --flake .#vbox-config` # default package is this flake
        vbox-config = nixpkgs-unstable.lib.nixosSystem {
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
          specialArgs = { inherit (inputs) agenix; nixpkgs = nixpkgs-unstable; };
        };

        # ova is designed to generate a VirtualBox Appliance output
        ova = nixpkgs-unstable.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            (import "${nixpkgs}/nixos/modules/virtualisation/virtualbox-image.nix")
            ./configuration.nix
            ./agenix.nix
            inputs.agenix.nixosModules.age
            inputs.home-manager.nixosModules.home-manager
            home-manager-config
          ];
          specialArgs = { inherit (inputs) agenix; inherit nixpkgs; };
        };

        flash-drive-iso = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./configuration.nix
            #./agenix.nix
            inputs.agenix.nixosModules.age
            inputs.home-manager.nixosModules.home-manager
            home-manager-config
            "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
            ./laptop.nix
            ({ config, pkgs, ... }: {
              isoImage.isoBaseName = "johnos";
            })
          ];
          specialArgs = { inherit (inputs) agenix; inherit nixpkgs; };
        };


        rpi-sdcard =
          let
            nixpkgs = inputs.rpinixpkgs;
          in
          inputs.nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
              #            ./configuration.nix
              ({ config, nixpkgs, ... }: {
                config.nixpkgs.crossSystem = nixpkgs.lib.systems.examples.raspberryPi;
              })
              "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/sd-image-raspberrypi.nix"
            ];
            specialArgs = { inherit (inputs) nixpkgs; };
          };

        rpi-sdcard_release-2009 =
          let
            nixpkgs = inputs.nixpkgs_release-2009;
          in
          nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
              #            ./configuration.nix
              ({ config, nixpkgs, ... }: {
                config.nixpkgs.crossSystem = nixpkgs.lib.systems.examples.raspberryPi;
              })
              "${nixpkgs}/nixos/modules/installer/cd-dvd/sd-image-raspberrypi.nix"
            ];
            specialArgs = { inherit nixpkgs; };
          };

        rpi-sdcard_release-2105 =
          let
            nixpkgs = inputs.nixpkgs_release-2105;
          in
          nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
              #            ./configuration.nix
              ({ config, nixpkgs, ... }: {
                config.nixpkgs.crossSystem = nixpkgs.lib.systems.examples.raspberryPi;
              })
              "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-raspberrypi.nix"
            ];
            specialArgs = { inherit nixpkgs; };
          };
      };

      packages.x86_64-linux = {
        flash-drive-iso = nixosConfigurations.flash-drive-iso.config.system.build.isoImage;
        ova = nixosConfigurations.ova.config.system.build.virtualBoxOVA;
        vbox-config = nixosConfigurations.vbox-config;
      };

      #        defaultPackage.x86_64-linux = packages.x86_64-linux.flash-drive-iso;
      defaultPackage.x86_64-linux = packages.x86_64-linux.vbox-config;
    };

}
