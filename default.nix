# build an ISO image that will auto install NixOS and reboot
# $ nix-build make-iso.nix
{...}:
let
   config = (import <nixpkgs/nixos/lib/eval-config.nix> {
     system = "x86_64-linux";
     modules = [
       <nixpkgs/nixos/modules/installer/cd-dvd/iso-image.nix>
       ./iso.nix
       ./ssh.nix
       ./networking.nix
       ./display.nix
       ./users.nix
       ./packages.nix
     ];
   }).config;
in {
  johnos = config.system.build.isoImage;
}