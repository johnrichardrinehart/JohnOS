{ lib, pkgs, ... }:
let
  listOfFiles = builtins.attrNames (lib.filterAttrs (_: v: v == "regular") (builtins.readDir ./radxa_patches));
  listOfPatches = builtins.trace "${builtins.toString (builtins.length listOfFiles)}" lib.filter (v: (builtins.match ".*\.patch" v) != null) listOfFiles;
  patches = builtins.map (p: { name = p; patch = ./radxa_patches + /${p}; }) listOfPatches;
in
{
  nixpkgs.overlays = [
    (self: super: {
      radxaLinux = pkgs.linuxPackagesFor (
        pkgs.buildLinux {
          src = pkgs.fetchFromGitHub {
            owner = "radxa";
            repo = "kernel";
            #ref = "linux-6.1-stan-rkr1";
            rev = "91727f5354c23539aa50f103f36fb9e200e04072";
            hash = "sha256-a+DL8OF+cyDRvRUszYb4T24O6OtcTugOev0jYxq/BR4=";
          };

          version = "6.1.84";

          defconfig = "rockchip_linux_defconfig";
        }
      );
    })
  ];

  boot.kernelPatches = patches;

  boot.kernelPackages = pkgs.radxaLinux;
}
