{ lib, pkgs, ... }:
let
  listOfFiles = builtins.attrNames (lib.filterAttrs (_: v: v == "regular") (builtins.readDir ./collabora_patches));
  listOfPatches = lib.filter (v: (builtins.match ".*\.patch" v) != null) listOfFiles;
  patches = builtins.map (p: { name = p; patch = ./collabora_patches + /${p}; }) listOfPatches;
in
{
  nixpkgs.overlays = [
    (self: super: {
      # this linux doesn't work for some reason
      linuxRock5C = pkgs.linuxPackagesFor (
        (pkgs.linux_latest.override {
          defconfig = "rockchip_linux_defconfig";
          argsOverride =
            let
              version = "6.12.0";
            in
            {
              inherit version;
              modDirVersion = version;
              src = pkgs.fetchgit {
                url = "https://gitlab.collabora.com/hardware-enablement/rockchip-3588/linux.git/";
                rev = "f7e1ed901e7c3a426bde1a787c3bd1ecf45eb410";
                hash = "sha256-t+dtZHyIpPGd/ED/GiQTr9GMTUeBefH8cDt6KuHTmpw=";
              };
            };

          structuredExtraConfig = with lib.kernel; {
            EARLY_PRINTK = yes;
            CONFIG_DEBUG = yes;
          };
        })
      );
    })
  ];

  # these are designed for v6.10
  boot.kernelPatches = patches;

  boot.kernelPackages = lib.mkForce pkgs.linuxRock5C;
}
