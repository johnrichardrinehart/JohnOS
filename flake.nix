{
  nixConfig = {
    #    substituters = [
    #      "https://johnos.cachix.org"
    #    ];
    #
    #    extra-trusted-public-keys = [
    #      "johnos.cachix.org-1:wwbcQLNTaO9dx0CIXN+uC3vFl8fvhtkJbZWzMXWLFu0="
    #    ];
  };

  inputs = {
    # TODO: remove when https://github.com/NixOS/nixpkgs/pull/159255 lands in unstable
    #nixpkgs_unstable.url = "github:NixOS/nixpkgs/master";
    nixpkgs_unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-templates.url = "github:NixOS/templates";

    nix-master.url = "github:NixOS/nix/master";
    nix-2_6_1.url = "github:nixos/nix/e044ccb67ce38d11059de32515306f5f1bd2f04f";

    home-manager = {
      url = "github:nix-community/home-manager/release-21.11";
      flake = true;
      inputs.nixpkgs.follows = "nixpkgs_unstable";
    };
  };

  outputs = inputs:
    let
      nix_pkg = inputs.nix-2_6_1.packages.x86_64-linux.nix;

      nixpkgs-unstable = inputs.nixpkgs_unstable;

      home-manager-config = {
        config = {
          home-manager = {
            useUserPackages = true;
            users.john = ./users/john.nix;
            users.ardan = ./users/ardan.nix;
            extraSpecialArgs = { photo = photoDerivation; };
          };
        };
      };

      photoDerivation =
        let
          pkgs = import nixpkgs-unstable { system = "x86_64-linux"; };
        in
        import ./photo/photo.nix { inherit pkgs; };
    in
    rec {
      nixosConfigurations = {
        nixos = nixosConfigurations.vbox-config;

        # vbox_config is designed to be used within a pre-existing NixOS installation as
        # `nixos-rebuild switch --flake .#vbox-config` # default package is this flake
        vbox-config =
          let
            nixpkgs = nixpkgs-unstable;
          in
          nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
              ./modules/machines/virtualbox.nix
              ./modules/configuration.nix
              inputs.home-manager.nixosModules.home-manager
              home-manager-config
            ];
            specialArgs = { inherit (inputs) flake-templates; inherit nixpkgs nix_pkg; };
          };

        vultr =
          let
            nixpkgs = nixpkgs-unstable;
          in
          nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
              ./modules/configuration.nix
              ./modules/machines/vultr.nix
              inputs.home-manager.nixosModules.home-manager
              home-manager-config
            ];
            specialArgs = { inherit (inputs) agenix flake-templates; inherit nixpkgs nix_pkg; };
          };

        # ova is designed to generate a VirtualBox Appliance output
        ova =
          let
            nixpkgs = nixpkgs-unstable;
          in
          nixpkgs-unstable.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
              (import "${nixpkgs}/nixos/modules/virtualisation/virtualbox-image.nix")
              ./configuration.nix
              inputs.home-manager.nixosModules.home-manager
              home-manager-config
            ];
            specialArgs = { inherit (inputs); inherit nixpkgs nix_pkg; };
          };

        vultr-iso =
          let nixpkgs = nixpkgs-unstable; in
          nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
              ./modules/machines/vultr.nix
              "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
              ({ config, pkgs, ... }: {
                isoImage = {
                  isoBaseName = "johnos_" + (inputs.self.rev or "dirty");
                };
              })
            ];
            specialArgs = { inherit nixpkgs; };
          };

        mbp-live-iso =
          let
            nixpkgs = nixpkgs-unstable;
          in
          nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";

            modules = [
              ./modules/machines/mbp.nix
              ./modules/configuration.nix
              inputs.home-manager.nixosModules.home-manager
              {
                config = {
                  home-manager = {
                    useUserPackages = true;
                    users.sergey = ./users/sergey.nix;
                    extraSpecialArgs = { photo = photoDerivation; };
                  };
                };
              }
              "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
              ({ config, pkgs, ... }: {
                isoImage = {
                  isoBaseName = "CergeyOS-" + (inputs.self.rev or "dirty");
                  makeEfiBootable = true;
                };
              })
            ];
            specialArgs = { inherit (inputs) flake-templates; inherit nixpkgs nix_pkg; };
          };

	simple-live-iso =
	let
		nixpkgs = nixpkgs-unstable;
	in
          nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";

            modules = [
		./modules/kernel.nix
              ./modules/configuration.nix
              inputs.home-manager.nixosModules.home-manager
              home-manager-config
              "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
              ({ config, pkgs, ... }: {
                isoImage = {
                  isoBaseName = "JohnOS-" + (inputs.self.rev or "dirty");
                  makeEfiBootable = true;
                };
              })
            ];
            specialArgs = { inherit (inputs) flake-templates; inherit nixpkgs nix_pkg; };
          };

        spectre-live-iso =
          let
            nixpkgs = nixpkgs-unstable;
          in
          nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";

            modules = [
              ./modules/machines/hp_spectre_x360.nix
              ./modules/configuration.nix
              inputs.home-manager.nixosModules.home-manager
              home-manager-config
              "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
              ({ config, pkgs, ... }: {
                isoImage = {
                  isoBaseName = "JohnOS-" + (inputs.self.rev or "dirty");
                  makeEfiBootable = true;
                };
              })
            ];
            specialArgs = { inherit (inputs) flake-templates; inherit nixpkgs nix_pkg; };
          };
      };

      packages.x86_64-linux = {
        vultr-iso = nixosConfigurations.vultr-iso.config.system.build.isoImage;
        spectre-live-iso = nixosConfigurations.spectre-live-iso.config.system.build.isoImage;
        mbp-live-iso = nixosConfigurations.mbp-live-iso.config.system.build.isoImage;
        ova = nixosConfigurations.ova.config.system.build.virtualBoxOVA;
        vbox-config = nixosConfigurations.vbox-config;
        simple-live-iso = nixosConfigurations.simple-live-iso.config.system.build.isoImage;
      };
    };
}
