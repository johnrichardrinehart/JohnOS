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
    # we can roll the branch back to nixos-unstable once
    # https://github.com/NixOS/nixpkgs/pull/174091/files
    # lands in nixos-unstable
    #nixpkgs.url = "github:nixos/nixpkgs/master";
    nixpkgs.url = "github:johnrichardrinehart/nixpkgs/johnrichardrinehart/sqitch-upgraded-templates";

    flake-templates.url = "github:NixOS/templates/master";

    nix.url = "github:NixOS/nix/master"; # or 2.11-maintenance vs. master

    home-manager = {
      url = "github:nix-community/home-manager/master";
      flake = true;
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
    };

    rust-overlay.url = "github:oxalica/rust-overlay";

    hyprland = {
      url = "github:hyprwm/Hyprland";
# build with your own instance of nixpkgs
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-templates, nix, home-manager, nixos-hardware, rust-overlay, hyprland }:

    let
      system = "x86_64-linux";
      nix = self.inputs.nix.packages.${system}.nix;

      home-manager-config = {
        config = {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            users.john = ./users/john.nix;
            users.ardan = ./users/ardan.nix;
            extraSpecialArgs = { photo = photoDerivation; };
          };
        };
      };

      photoDerivation =
        let
          pkgs = import nixpkgs { system = "x86_64-linux"; };
        in
        import ./photo/photo.nix { inherit pkgs; };

      minikube-beta =
        let
          pkgs = nixpkgs.legacyPackages."x86_64-linux";
          lib = pkgs.lib;
          version = "v1.26.0-beta.1";
          src = pkgs.fetchFromGitHub {
            owner = "kubernetes";
            rev = "${version}";
            repo = "minikube";
            sha256 = "sha256-oafO/K7+oXxp/SyvjcKdXZ+mOUVrrgcVuFmCyoNPbaw=";
          };
          name = "minikube-${version}";
        in
        (pkgs.callPackage "${pkgs.path}/pkgs/applications/networking/cluster/minikube" {
          vmnet = pkgs.darwin.apple_sdk.framworks.vmnet;
          buildGoModule = args: pkgs.buildGoModule (args // {
            inherit name src version;
            vendorSha256 = "sha256-JtNlvTSnlPuhr0nsBkH6Ke+Y6fCFyBAlduSPcMS8SS4=";
          });
        });

      myOverlays = (import ./modules/overlays.nix) ++ [
        (self: super: {
          inherit minikube-beta;
        })
      ];

    in
    rec {
      nixosConfigurations = {
        # vbox_config is designed to be used within a pre-existing NixOS installation as
        # `nixos-rebuild switch --flake .#vbox-config` # default package is this flake
        vbox-config = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./modules/machines/virtualbox.nix
            ./modules/configuration.nix
            home-manager.nixosModules.home-manager
            home-manager-config
          ];
          specialArgs = { inherit flake-templates; inherit nixpkgs nix; };
        };

        vultr = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./modules/configuration.nix
            ./modules/machines/vultr.nix
            home-manager.nixosModules.home-manager
            home-manager-config
          ];
          specialArgs = { inherit flake-templates; inherit nixpkgs nix; };
        };

        # ova is designed to generate a VirtualBox Appliance output
        ova = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            (import "${nixpkgs}/nixos/modules/virtualisation/virtualbox-image.nix")
            ./modules/configuration.nix
            home-manager.nixosModules.home-manager
            home-manager-config
          ];
          specialArgs = { inherit nixpkgs nix; };
        };

        vultr-iso = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./modules/machines/vultr.nix
            "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
            ({ config, pkgs, ... }: {
              isoImage = {
                isoBaseName = "johnos_" + (self.rev or "dirty");
              };
            })
          ];
          specialArgs = { inherit nixpkgs; };
        };

        mbp-live-iso = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";

          modules = [
            ./modules/machines/mbp.nix
            ./modules/configuration.nix
            home-manager.nixosModules.home-manager
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
                isoBaseName = "CergeyOS-" + (self.rev or "dirty");
                makeEfiBootable = true;
              };
            })
          ];
          specialArgs = { inherit flake-templates; inherit nixpkgs nix; };
        };

        framework-laptop = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";

          modules = [

            hyprland.nixosModules.default
            { programs.hyprland.enable = true; }

            nixos-hardware.nixosModules.framework
            ./modules/kernel.nix
            ./modules/configuration.nix
            ./modules/machines/framework.nix
            home-manager.nixosModules.home-manager
            home-manager-config
            ({ config, pkgs, lib, ... }: {
              fonts.fontconfig.enable = pkgs.lib.mkForce true;
              services.sshd.enable = true;
              virtualisation.containers.enable = true;
              nixpkgs.overlays = myOverlays ++ [ rust-overlay.overlays.default ];
              environment.systemPackages = [ pkgs.rust-bin.stable.latest.default ];
            })
          ];
          specialArgs = { inherit flake-templates; inherit nixpkgs nix hyprland; };
        };

        simple-live-iso = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";

          modules = [
            nixos-hardware.nixosModules.framework
            ./modules/kernel.nix
            ./modules/configuration.nix
            ./modules/machines/framework.nix
            home-manager.nixosModules.home-manager
            home-manager-config
            ({ config, pkgs, lib, ... }: {
              # boot.initrd.kernelModules = [ "i915" ];
              # boot.kernelParams = [ "acpi_backlight=vendor" ];
              # boot.blacklistedKernelModules = [ "modesetting" "nvidia" ];

              # Fix font sizes in X
              #services.xserver.dpi = 200;
              fonts.fontconfig.enable = pkgs.lib.mkForce true;
            })
          ];
          specialArgs = { inherit flake-templates; inherit nixpkgs nix; };
        };

        spectre-live-iso = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";

          modules = [
            ./modules/configuration.nix
            ./modules/kernel.nix
            ./modules/machines/hp_spectre_x360.nix
            home-manager.nixosModules.home-manager
            home-manager-config
            "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
          ];
          specialArgs = { inherit flake-templates; inherit nixpkgs nix; photo = photoDerivation; };
        };

        gce = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./modules/configuration.nix
            ./modules/kernel.nix
            ./modules/machines/gce.nix
            "${nixpkgs}/nixos/modules/virtualisation/google-compute-image.nix"
          ];
          specialArgs = { inherit flake-templates; inherit nixpkgs nix; };
        };
      };

      packages.x86_64-linux = {
        # local configurations
        spectre-live-iso = nixosConfigurations.spectre-live-iso.config.system.build.isoImage;
        mbp-live-iso = nixosConfigurations.mbp-live-iso.config.system.build.isoImage;

        # cloud configurations
        vultr-iso = nixosConfigurations.vultr-iso.config.system.build.isoImage;
        gce = nixosConfigurations.gce.config.system.build.googleComputeImage;

        # VM configurations
        ova = nixosConfigurations.ova.config.system.build.virtualBoxOVA;
        vbox-config = nixosConfigurations.vbox-config.config.system.build.toplevel;
      };
    };
}
