{ lib, pkgs, ... }:
let
  listOfFiles = builtins.attrNames (
    lib.filterAttrs (_: v: v == "regular") (builtins.readDir ./6.10_patches)
  );
  listOfPatches = lib.filter (v: (builtins.match ".*.patch" v) != null) listOfFiles;
  patches = builtins.map (p: {
    name = p;
    patch = ./6.10_patches + /${p};
  }) listOfPatches;
in
{
  nixpkgs.overlays = [
    (self: super: {
      # this linux doesn't work for some reason
      linuxRock5C = pkgs.linuxPackagesFor (
        (pkgs.linux_latest.override {
          argsOverride =
            let
              version = "6.13";
            in
            {
              inherit version;
              modDirVersion =
                if builtins.length (builtins.splitVersion version) == 2 then (version + ".0") else version;
              src = pkgs.fetchurl {
                url = "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${version}.tar.xz";

                hash = "sha256-553Mbrhmlca6v7B8KGGRK2NdUHXGzRzQVn0eoVX4DW4=";
                #hash = "";
              };
            };

          structuredExtraConfig = with lib.kernel; {
            EARLY_PRINTK = yes;
            CONFIG_DEBUG = yes;
            CONFIG_DYNAMIC_DEBUG = yes;
          };
        })
      );
    })
  ];

  boot.kernelPackages = lib.mkForce pkgs.linuxRock5C;
}
