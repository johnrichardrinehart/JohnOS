flakeInputs@{home-manager, nixos-hardware, nixpkgs, ...}:
let
  home-manager = flakeInputs.home-manager;
  nixos-hardware = flakeInputs.nixos-hardware;
in
{
  modules = [
    nixos-hardware.nixosModules.framework-11th-gen-intel
    ../../modules/home-manager.nix
    ../../modules/desktop.nix
    ../../modules/system.nix
    ../../modules/kernel.nix
    ./framework.nix
    home-manager.nixosModules.home-manager
    ({ config, pkgs, lib, nixpkgs, ... }: {
      nixpkgs.hostPlatform = "x86_64-linux";
      boot.loader.systemd-boot.enable = true;
      boot.loader.efi.canTouchEfiVariables = true;
      fonts.fontconfig.enable = pkgs.lib.mkForce true;
      services.sshd.enable = true;
      virtualisation.containers.enable = true;
      nixpkgs.config.permittedInsecurePackages = [
        "electron-25.9.0"
      ];
    })
  ];

  specialArgs = { inherit (flakeInputs) nixpkgs flake-templates; };
}
