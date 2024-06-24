{ ... }: {
  imports = [
    ../../modules/system.nix
    ./framework.nix
    ({ lib, ... }: {
      boot.loader.systemd-boot.enable = true;
      boot.loader.efi.canTouchEfiVariables = true;
      fonts.fontconfig.enable = lib.mkForce true;
      services.sshd.enable = true;
      virtualisation.containers.enable = true;
    })
  ];
}
