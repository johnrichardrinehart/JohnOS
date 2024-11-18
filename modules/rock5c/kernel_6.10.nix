{ lib, pkgs, ... }:
{
  nixpkgs.overlays = [
    (self: super: {
      # this linux doesn't work for some reason
      linuxRock5C = pkgs.linuxPackagesFor (
        (pkgs.linux_latest.overrideAttrs {
          #src = /home/john/linux; // 11 GiB !!!
        }).override
          {
            defconfig = "rockchip_linux_defconfig";
            argsOverride =
              let
                version = "6.11.9";
              in
              {
                inherit version;
                modDirVersion = version;
                src = pkgs.fetchurl {
                  #url = "mirror://kernel/linux/v6.x/linux-6.11.tar.xz";
                  url = "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.11.9.tar.xz";

                  hash = "sha256-dWWKeqO9lZjJbuHlhixeHTT87XXCjYJccnoVEKbzhLQ=";
                };
                #src = pkgs.fetchurl {
                #  url = "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.11.9.tar.xz";
                #  postFetch = ''
                #    tmp=$(mktemp -d);
                #    ${pkgs.gnutar}/bin/tar xf "$downloadedFile" -C$tmp --strip-components=1;
                #    rm -rf $out;
                #    mv $tmp $out;
                #  '';
                #};
                #src = lib.fileset.toSource {
                #  root = /home/john/linux;
                #  fileset = lib.fileset.union [
                #    (pkgs.fetchTree {
                #      url = "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.11.9.tar.xz";
                #      narHash = lib.fakeHash;
                #      type = "file";
                #    })
                #  ];
                #  #lib.fileset.gitTracked /home/john/linux;
                #};
              };

            structuredExtraConfig = with lib.kernel; {
              EARLY_PRINTK = yes;
              CONFIG_DEBUG = yes;
            };
          }
      );
    })
  ];

  # these are designed for v6.10
  boot.kernelPatches =
    [
    ];

  boot.kernelPackages = lib.mkForce pkgs.linuxRock5C;
}
