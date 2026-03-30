{
  stdenv,
  fetchurl,
}:
stdenv.mkDerivation {
  pname = "mali-g610-firmware";
  version = "v1.9-1-2131373";

  src = fetchurl {
    url = "https://raw.githubusercontent.com/tsukumijima/libmali-rockchip/v1.9-1-2131373/firmware/g610/mali_csffw.bin";
    hash = "sha256-YP+jdu3sjEAtwO6TV8aF2DXsLg+z0HePMD0IqYAtV/E=";
  };

  buildCommand = ''
    install -Dm444 $src $out/lib/firmware/arm/mali/arch10.8/mali_csffw.bin
  '';
}
