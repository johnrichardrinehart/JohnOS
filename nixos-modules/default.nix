{ inputs, ... }:
{
  nixpkgs.overlays = [ inputs.self.overlays.default ];

  imports = [
    ./auto-suspend.nix
    ./bluetooth.nix
    ./droidcam.nix
    ./filepicker.nix
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
    ./thunderbolt-debug.nix
    ./virtualisation.nix

    ./desktop/default.nix
    ./desktop/hyprland.nix
    ./desktop/greetd+niri.nix
    ./desktop/xmonad.nix
    ./desktop/xorg-xmonad.nix
    ./desktop/xorg.nix

    ./bootloader
    ./kernel
    ./rock5c
  ];
}
