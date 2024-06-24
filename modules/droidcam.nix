# httpn://discourse.nixos.org/t/load-automatically-kernel-module-and-deal-with-parameters/9200
{ pkgs, config, lib, ... }:
let
  cfg = config.dev.johnrinehart.droidcam;
  droidcamDrv =
  let
    stdenv = pkgs.stdenv;
    kernel = config.boot.kernelPackages.kernel;
  in
  stdenv.mkDerivation rec {
    pname = "v4l2loopback-dc";
    version = "0.0.1";

    src = pkgs.fetchFromGitHub {
      owner = "aramg";
      repo = "droidcam";
      rev = "v1.8.1";
      sha256 = "3iA7GDTiCx5vHawj8ZBFAK0BIfmxEFuQrVfL7Gi6FhM=";
    };

    sourceRoot = "source/v4l2loopback";

    # https://github.com/SebTM/nixpkgs/blob/1a92639f290e05d823282ed9a0145d2b82b3c1f6/pkgs/os-specific/linux/sysdig/default.nix#L76-L80
    postUnpack = lib.optionalString (lib.versionAtLeast kernel.version "6.8") ''
      substituteInPlace source/v4l2loopback/v4l2loopback-dc.c --replace-fail "strlcpy" "strscpy"
    '';

    KVER = kernel.modDirVersion;
    KBUILD_DIR = "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build";

    nativeBuildInputs = kernel.moduleBuildDependencies;

    makeFlags = [
      "KERNELRELEASE=${kernel.modDirVersion}"
      "KERNEL_DIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
    ];

    installPhase = ''
      mkdir -p $out/lib/modules/${KVER}/kernels/media/video
      cp v4l2loopback-dc.ko $out/lib/modules/${KVER}/kernels/media/video/
    '';

    meta = with pkgs.stdenv.lib; {
      description = "DroidCam kernel module v4l2loopback-dc";
      homepage = https://github.com/aramg/droidcam;
    };
  };

in {
  options.dev.johnrinehart.droidcam = {
    enable = lib.mkEnableOption "DroidCam V4L2 plug-in";
  };

  config = lib.mkIf cfg.enable {
    # below stolen from https://gist.github.com/TheSirC/93130f70cc280cdcdff89faf8d4e98ab
    environment.systemPackages = [ pkgs.droidcam ];
    boot.extraModulePackages = [ droidcamDrv ];
    boot.kernelModules = [ "v4l2loopback-dc" ];
  };
}
