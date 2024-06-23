{ ... }: {
  imports = [
    ../../modules/home-manager.nix
    ../../modules/desktop.nix
    ../../modules/system.nix
    ../../modules/kernel.nix
    ./framework.nix
    ({ lib, ... }: {
      nixpkgs = {
        hostPlatform = "x86_64-linux";
        config.permittedInsecurePackages = [
          "electron-25.9.0"
        ];
      };
      boot.loader.systemd-boot.enable = true;
      boot.loader.efi.canTouchEfiVariables = true;
      fonts.fontconfig.enable = lib.mkForce true;
      services.sshd.enable = true;
      virtualisation.containers.enable = true;
    })
  ];
}
