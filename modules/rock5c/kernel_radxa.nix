{ lib, pkgs, ... }: {
    nixpkgs.overlays = [
      (self: super: {
        radxaLinux = pkgs.linuxPackagesFor (pkgs.buildLinux {
          src = pkgs.fetchFromGitHub {
            owner = "radxa";
            repo = "kernel";
            #ref = "linux-6.1-stan-rkr1";
            rev = "428a0a5e6a6bfc1b24506318c421f4582ab3da11";
            hash = "sha256-c/RwvCmm002yo+i0kHtkViSzPdxeWWjkZ2j8fJTw9EM=";
          };

          version = "6.1.43";

          defconfig = "rockchip_linux_defconfig";
        });
      })
    ];

    boot.kernelPackages = lib.mkForce pkgs.radxaLinux;
}

