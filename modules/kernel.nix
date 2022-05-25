{ nixpkgs, pkgs, lib, ... }:
{
  nixpkgs.config.allowBroken = true; # zfs-kernel-$VERSION is broken

  # add JohnOS-kernel as a package
  nixpkgs.overlays = [
    (
      self: super: {
        JohnOS-kernel =
          let
            v = "5.18";
            os_name = "-JohnOS";
          in
          super.linuxPackagesFor (super.linux_latest.override {
            argsOverride = rec {
              src = super.fetchurl {
                url = "mirror://kernel/linux/kernel/v5.x/linux-${version}.tar.xz";
                sha256 = "sha256-UfPxaEqJbnlxgqCQcpnMHw/15bUd2aVUeK5jpAmFXO4=";
              };


              version = v;

              # stoled from https://github.com/NixOS/nixpkgs/blob/4f6e9865dd33d5635024a1164e17da5aa3af678a/pkgs/os-specific/linux/kernel/linux-5.18.nix#L8-L9
              modDirVersion = lib.concatStringsSep "." (lib.take 3 (lib.splitVersion "${v}.0")) + "${os_name}";

              extraConfig = ''
                LOCALVERSION ${os_name}
                LOCALVERSION_AUTO y
              '';
            };
          });
      }
    )
  ];

  boot.kernelPackages = pkgs.JohnOS-kernel;
}
