{ ... }: {
  imports = [
    ./bluetooth.nix
    ./droidcam.nix
    ./fonts.nix
    ./ide.nix
    ./locale.nix
    ./network.nix
    ./packages.nix
    ./ssh.nix
    ./sound.nix
    ./system.nix
    ./virtualisation.nix

    ./bootloader
    ./desktop
    ./home-manager
    ./kernel
  ];
}
