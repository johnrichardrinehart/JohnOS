{ nixpkgs, pkgs, lib, ...}:
{
  nixpkgs.config.allowBroken = true; # zfs-kernel-$VERSION is broken
  boot.kernelPackages = pkgs.lib.mkForce (
    let
      latest_stable_pkg = { fetchurl, buildLinux, ... } @ args:
        buildLinux (args // rec {
          version = "5.16.12";
          modDirVersion = "5.16.12";

	  kernelPatches = [];

          src = fetchurl {
            url = "https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-${version}.tar.xz";
            sha256 = "sha256-u1od8VoQpxWAekSHL/T+d1M3quRFKFGB8dG6DHix1/I=";
          };

        } // (args.argsOverride or { }));
      latest_stable = pkgs.callPackage latest_stable_pkg { };
    in
    pkgs.recurseIntoAttrs
      (pkgs.linuxPackagesFor latest_stable)
  );
}
