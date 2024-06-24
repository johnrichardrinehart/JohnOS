{ ... }: {
  imports = [
    ./droidcam.nix
    ./fonts.nix
    ./ide.nix
    ./locale.nix
    ./packages.nix

    ./bootloader
    ./desktop
    ./home-manager
    ./kernel
  ];
}
