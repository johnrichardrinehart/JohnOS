{ ... }: {
  imports = [
    ../../modules/home-manager.nix
    ../../modules/system.nix
    ./framework.nix
    ({ lib, ... }: {
      nixpkgs = {
        hostPlatform = "x86_64-linux";
        config = {
          allowUnfree = true;
          permittedInsecurePackages = [
            "electron-25.9.0"
          ];
          allowUnsupportedSystem = true;
        };
      };
      boot.loader.systemd-boot.enable = true;
      boot.loader.efi.canTouchEfiVariables = true;
      fonts.fontconfig.enable = lib.mkForce true;
      services.sshd.enable = true;
      virtualisation.containers.enable = true;
    })
  ];
}
