{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    flake-templates.url = "github:NixOS/templates/master";

    nix.url = "github:NixOS/nix/2.17-maintenance"; # or 2.11-maintenance vs. master
    home-manager = {
      url = "github:nix-community/home-manager/master";
      flake = true;
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
    };

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs: {
    nixosConfigurations = import ./hosts inputs;
  };
#    let
#     system = "x86_64-linux";
#     nix = inputs.nix.packages.${system}.nix;
#
#     photoDerivation =
#       let
#         pkgs = import inputs.nixpkgs { system = "x86_64-linux"; };
#       in
#       import ./photo/photo.nix { inherit pkgs; };
#    in
#    rec {
#      nixosConfigurations = {
#        vbox-config = inputs.nixpkgs.lib.nixosSystem {
#          system = "x86_64-linux";
#          modules = [
#            ./hosts/virtualbox
#            ./modules/system.nix
#            inputs.home-manager.nixosModules.home-manager
#            #home-manager-config
#          ];
#          specialArgs = { inherit (inputs) flake-templates nixpkgs nix; };
#        };
#
#        vultr = inputs.nixpkgs.lib.nixosSystem {
#          system = "x86_64-linux";
#          modules = [
#            ./modules/system.nix
#            ./hosts/vultr
#            inputs.home-manager.nixosModules.home-manager
#            #home-manager-config
#          ];
#          specialArgs = { inherit (inputs) flake-templates nixpkgs nix; };
#        };
#
#        # VirtualBox Appliance output
#        ova = inputs.nixpkgs.lib.nixosSystem {
#          system = "x86_64-linux";
#          modules = [
#            (import "${inputs.nixpkgs}/nixos/modules/virtualisation/virtualbox-image.nix")
#            ./modules/system.nix
#            inputs.home-manager.nixosModules.home-manager
#            #home-manager-config
#          ];
#          specialArgs = { inherit (inputs) flake-templates nixpkgs nix; };
#        };
#
#        vultr-iso = inputs.nixpkgs.lib.nixosSystem {
#          system = "x86_64-linux";
#          modules = [
#            ./hosts/vultr
#            "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
#            ({ config, pkgs, ... }: {
#              boot.swraid.enable = pkgs.lib.mkForce false;
#              isoImage = {
#                isoBaseName = "johnos_" + (inputs.self.rev or "dirty");
#              };
#            })
#          ];
#          specialArgs = { inherit (inputs) nixpkgs; };
#        };
#
#        mbp-live-iso = inputs.nixpkgs.lib.nixosSystem {
#          system = "x86_64-linux";
#
#          modules = [
#            ./hosts/mbp
#            ./modules/system.nix
#            inputs.home-manager.nixosModules.home-manager
#            ({ config, pkgs, ...}: {
#              config = {
#                boot.swraid.enable = pkgs.lib.mkForce false;
#                users.users.sergey.isNormalUser = true;
#                home-manager = {
#                  useUserPackages = true;
#                  users.sergey = ./home-manager/users/sergey.nix;
#                  extraSpecialArgs = { photo = photoDerivation; };
#                };
#              };
#            })
#            "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
#            ({ config, pkgs, ... }: {
#              isoImage = {
#                isoBaseName = "SergeyOS-" + (inputs.self.rev or inputs.self.dirtyRev);
#                makeEfiBootable = true;
#              };
#            })
#          ];
#          specialArgs = { inherit (inputs) flake-templates nixpkgs nix; };
#        };
#
#        framework-laptop = inputs.nixpkgs.lib.nixosSystem (
#          import ./hosts/framework/default.nix inputs
#          #(import ./hosts/framework/default.nix { home-manager = inputs.home-manager; nixos-hardware = inputs.nixos-hardware; })
#        );
#
#        simple-live-iso = inputs.nixpkgs.lib.nixosSystem {
#          system = "x86_64-linux";
#
#          modules = [
#            inputs.nixos-hardware.nixosModules.framework-11th-gen-intel
#            ./modules/kernel.nix
#            ./modules/system.nix
#            ./hosts/framework
#            inputs.home-manager.nixosModules.home-manager
#            #home-manager-config
#            ({ config, pkgs, lib, ... }: {
#              boot.loader.grub.devices = ["/dev/sda1"];
#              fonts.fontconfig.enable = pkgs.lib.mkForce true;
#            })
#          ];
#          specialArgs = { inherit (inputs) flake-templates nixpkgs nix nixos-hardware; };
#        };
#
#        spectre-live-iso = inputs.nixpkgs.lib.nixosSystem {
#          system = "x86_64-linux";
#
#          modules = [
#            ./modules/system.nix
#            ./modules/kernel.nix
#            ./hosts/hp_spectre_x360
#            inputs.home-manager.nixosModules.home-manager
#            #home-manager-config
#            "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
#          ];
#          specialArgs = { inherit (inputs) flake-templates nixpkgs nix; photo = photoDerivation; };
#        };
#
#        gce = inputs.nixos-generators.nixosGenerate {
#          system = "x86_64-linux";
#          modules = [
#            ./modules/system.nix
#            ./modules/kernel.nix
#            ./hosts/gce
#            #({
#            #  nixpkgs.overlays = myOverlays;
#            #})
#          ];
#          format = "gce";
#          specialArgs = { inherit (inputs) flake-templates nixpkgs; };
#        };
#      };
#
#      packages.x86_64-linux = {
#        # local configurations
#        spectre-live-iso = nixosConfigurations.spectre-live-iso.config.system.build.isoImage;
#        mbp-live-iso = nixosConfigurations.mbp-live-iso.config.system.build.isoImage;
#        # cloud configurations
#        vultr-iso = nixosConfigurations.vultr-iso.config.system.build.isoImage;
#        gce = nixosConfigurations.gce;
#
#        # VM configurations
#        ova = nixosConfigurations.ova.config.system.build.virtualBoxOVA;
#        vbox-config = nixosConfigurations.vbox-config.config.system.build.toplevel;
#      };
#    };
}
