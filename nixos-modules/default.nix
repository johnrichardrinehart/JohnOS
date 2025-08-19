{ inputs, ... }:
{
  nixpkgs.overlays = [ inputs.self.overlays.default ];

  imports = [
    ./bluetooth.nix
    ./droidcam.nix
    ./fonts.nix
    ./gocryptfs.nix
    ./ide.nix
    ./laptop.nix
    ./locale.nix
    ./network.nix
    ./nix.nix
    ./packages.nix
    ./s3_mount.nix
    ./sops.nix
    ./sound.nix
    ./ssh.nix
    ./system.nix
    ./virtualisation.nix
    ./xmonad.nix

    ./bootloader
    ./desktop
    ./kernel
    ./rock5c
  ];
}
