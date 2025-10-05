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

    ./desktop/default.nix
    ./desktop/hyprland.nix
    ./desktop/xmonad.nix
    ./desktop/xorg-xmonad.nix
    ./desktop/xorg.nix

    ./bootloader
    ./kernel
    ./rock5c
  ];
}
