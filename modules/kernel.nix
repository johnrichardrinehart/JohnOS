{ nixpkgs, pkgs, lib, ... }:
{
  nixpkgs.config.allowBroken = true; # zfs-kernel-$VERSION is broken

  # add JohnOS-kernel as a package
  nixpkgs.overlays = [
    (
      self: super: {
        myLinux =
          let
            v = "6.3.1"; # before a bunch of ALSA usb-audio changes
            os_name = "-JohnOS";
          in
          super.linuxPackagesFor (super.linux_latest.override {
            argsOverride = rec {
              src = super.fetchurl {
                url = "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${v}.tar.xz";
                sha256 = "sha256-eGIPtKfV4NsdTrjVscbiB7pdGVZO+mOWelm22vibPyo=";
              };

              version = v;

              # stolen from https://github.com/NixOS/nixpkgs/blob/4f6e9865dd33d5635024a1164e17da5aa3af678a/pkgs/os-specific/linux/kernel/linux-5.18.nix#L8-L9
              modDirVersion =
                let
                  parts = builtins.filter (x: builtins.isString x) (builtins.split "-" v); # [ "6.0" "rc7" ]
                  number = lib.concatStrings (lib.take 1 parts); # "6.0"
                  suffix = lib.concatStrings (lib.sublist 1 1 parts); # "rc7"
                  digits = builtins.splitVersion "${number}"; # [ "6 "0" ]
                  extendedNumber =
                    if builtins.length digits < 3 then
                      if lib.stringLength suffix == 0 then
                        number + ".0"
                      else
                        number + ".0" + "-" + suffix
                    else
                      v;
                in
                extendedNumber + os_name;

              extraConfig = ''
                LOCALVERSION ${os_name}
                LOCALVERSION_AUTO y
              '';
            };
          });

        linux = self.myLinux.kernel;
      }
    )
  ];

  boot.kernelPackages = pkgs.myLinux;
}
