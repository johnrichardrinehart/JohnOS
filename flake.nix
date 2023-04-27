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
    nixpkgs.url = "github:nixos/nixpkgs/master";

    flake-templates.url = "github:NixOS/templates/master";

    #nix.url = "github:NixOS/nix/master"; # or 2.11-maintenance vs. master
    nix.url = "github:NixOS/nix/2.14-maintenance"; # or 2.11-maintenance vs. master

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

  outputs = { self, nixpkgs, flake-templates, nix, home-manager, nixos-hardware, nixos-generators }:
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
        (self: super: {
          # make every nixpkgs derivation only use the same nix as is in my system to
          # reduce an extra dependency.
          inherit nix; # use nix from input
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
            ./modules/system.nix
            home-manager.nixosModules.home-manager
            home-manager-config
          ];
          specialArgs = { inherit flake-templates; inherit nixpkgs nix; };
        };

        vultr = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./modules/system.nix
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
            ./modules/system.nix
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
            ./modules/system.nix
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
            nixos-hardware.nixosModules.framework
            ./modules/desktop.nix
            ./modules/system.nix
            ./modules/kernel.nix
            ./modules/machines/framework.nix
            home-manager.nixosModules.home-manager
            home-manager-config
            ({ config, pkgs, lib, ... }: {
              boot.loader.systemd-boot.enable = true;
              boot.loader.efi.canTouchEfiVariables = true;
              fonts.fontconfig.enable = pkgs.lib.mkForce true;
              services.sshd.enable = true;
              virtualisation.containers.enable = true;
              nixpkgs.overlays = myOverlays;
            })
          ];
          specialArgs = { inherit flake-templates; inherit nixpkgs; };
        };

        simple-live-iso = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";

          modules = [
            nixos-hardware.nixosModules.framework
            ./modules/kernel.nix
            ./modules/system.nix
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
            ./modules/system.nix
            ./modules/kernel.nix
            ./modules/machines/hp_spectre_x360.nix
            home-manager.nixosModules.home-manager
            home-manager-config
            "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
          ];
          specialArgs = { inherit flake-templates; inherit nixpkgs nix; photo = photoDerivation; };
        };

        gce = nixos-generators.nixosGenerate {
          system = "x86_64-linux";
          modules = [
            ./modules/system.nix
            ./modules/kernel.nix
            ./modules/machines/gce.nix
            ({
              nixpkgs.overlays = myOverlays;
            })
          ];
          format = "gce";
          specialArgs = { inherit flake-templates; inherit nixpkgs; };
        };
      };

      packages.x86_64-linux = {
        # local configurations
        spectre-live-iso = nixosConfigurations.spectre-live-iso.config.system.build.isoImage;
        mbp-live-iso = nixosConfigurations.mbp-live-iso.config.system.build.isoImage;

        # cloud configurations
        vultr-iso = nixosConfigurations.vultr-iso.config.system.build.isoImage;
        gce = nixosConfigurations.gce;

        # VM configurations
        ova = nixosConfigurations.ova.config.system.build.virtualBoxOVA;
        vbox-config = nixosConfigurations.vbox-config.config.system.build.toplevel;
      };
    };
}
