{ config, lib, nixpkgs, pkgs, ... }:
let cfg = config.dev.johnrinehart.kernel.tagged; in {
  options.dev.johnrinehart.kernel.tagged = {
    enable = lib.mkEnableOption "tagged kernel";
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.config.allowBroken = true; # zfs is broken (zfs-kernel-$VERSION) is broken
    # add JohnOS-kernel as a package
    nixpkgs.overlays = [
      (self: super:
        let
          kernelTag = "JohnOS";
        in
        {
          myLinux = super.linuxPackagesFor (super.linux_latest.override {
            argsOverride = {
              extraConfig = ''
                LOCALVERSION ${kernelTag}
                LOCALVERSION_AUTO y
              '';
            };
          });
        })
    ];

    boot.kernelPackages = pkgs.myLinux;
  };
}
