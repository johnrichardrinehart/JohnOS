# build an ISO image that will auto install NixOS and reboot
# $ nix-build make-iso.nix
{...}:
let
   config = (import <nixpkgs/nixos/lib/eval-config.nix> {
     system = "x86_64-linux";
     modules = [
       <nixpkgs/nixos/modules/installer/cd-dvd/iso-image.nix>
       ./custom.nix
       ./ssh.nix
     ];
   }).config;
in {
  johnos = config.system.build.isoImage;
}