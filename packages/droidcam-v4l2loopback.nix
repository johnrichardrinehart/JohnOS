{
  fetchFromGitHub,
  kernel,
  lib,
  stdenv,
}:

stdenv.mkDerivation rec {
  pname = "v4l2loopback-dc";
  version = "2.1.5";

  src = fetchFromGitHub {
    owner = "aramg";
    repo = "droidcam";
    rev = "v${version}";
    sha256 = "sha256-22lRmtXumjR/83Fg1edBisM1GjNZvNUvPs1Yg7Na1xw=";
  };

  sourceRoot = "source/v4l2loopback";

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

  meta = with lib; {
    description = "DroidCam kernel module v4l2loopback-dc";
    homepage = "https://github.com/aramg/droidcam";
    platforms = platforms.linux;
  };
}
