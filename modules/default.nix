{ ... }: {
  imports = [
    ./bootloader
    ./kernel
    ./desktop
    ./packages.nix
    ./locale.nix
    ./fonts.nix
    ./ide.nix
    ./droidcam.nix
  ];
}
