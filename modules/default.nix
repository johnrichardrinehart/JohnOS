{ ... }:
{
  imports = [
    ./bluetooth.nix
    ./droidcam.nix
    ./fonts.nix
    ./gocryptfs.nix
    ./ide.nix
    ./laptop.nix
    ./locale.nix
    ./network.nix
    ./packages.nix
    ./s3_mount.nix
    ./sound.nix
    ./ssh.nix
    ./system.nix
    ./virtualisation.nix

    ./bootloader
    ./desktop
    ./home-manager
    ./kernel
    ./rock5c
  ];
}
