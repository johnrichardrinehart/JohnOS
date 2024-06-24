{ ... }: {
  imports = [
    ./droidcam.nix
    ./fonts.nix
    ./ide.nix
    ./locale.nix
    ./network.nix
    ./packages.nix
    ./system.nix
    ./virtualisation.nix

    ./bootloader
    ./desktop
    ./home-manager
    ./kernel
  ];
}
