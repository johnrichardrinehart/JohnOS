# https://discourse.nixos.org/t/load-automatically-kernel-module-and-deal-with-parameters/9200
{ stdenv, fetchFromGitHub, kernel }:

stdenv.mkDerivation rec {
  pname = "v4l2loopback-dc";
  version = "0";

  src = fetchFromGitHub {
    owner = "aramg";
    repo = "droidcam";
    rev = "v1.8.1";
    sha256 = "3iA7GDTiCx5vHawj8ZBFAK0BIfmxEFuQrVfL7Gi6FhM=";
  };

  sourceRoot = "source/v4l2loopback";

  KVER = "${kernel.modDirVersion}";
  KBUILD_DIR = "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build";

  nativeBuildInputs = kernel.moduleBuildDependencies;

  makeFlags = [
    "KERNELRELEASE=${kernel.modDirVersion}"
    "KERNEL_DIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
  ] ;

  installPhase = ''
    mkdir -p $out/lib/modules/${KVER}/kernels/media/video
    cp v4l2loopback-dc.ko $out/lib/modules/${KVER}/kernels/media/video/
  '';

  meta = with stdenv.lib; {
    description = "DroidCam kernel module v4l2loopback-dc";
    homepage = https://github.com/aramg/droidcam;
  };
}
