{
  lib,
  stdenv,
  fetchFromGitHub,
  gcc-arm-embedded,
  gnumake,
  gawk,
  pkg-config,
  libftdi1,
  bash,
  git,
  inetutils,
  python3,
  perl,
  which,
  pname ? "framework-ec",
  version ? "unstable-2026-05-09",
  rev ? "f6620a8200e8d1b349078710b271540b5b8a1a18",
  hash ? "sha256-0raKJJug3T22XV1sX0nwIjx4ZOKlI3uoyLYOlMGdI/I=",
  board ? "hx20",
  supportsDisplayToggleKeyHid ? false,
  patches ? [ ],
}:

stdenv.mkDerivation {
  inherit pname version;

  patches = [
    ./framework-ec-ectool-display-toggle-key-hid.patch
  ]
  ++ patches;

  src = fetchFromGitHub {
    owner = "FrameworkComputer";
    repo = "EmbeddedController";
    inherit rev hash;
  };

  nativeBuildInputs = [
    bash
    gcc-arm-embedded
    git
    inetutils
    gnumake
    gawk
    pkg-config
    python3
    perl
    which
  ];

  buildInputs = [
    libftdi1
  ];

  dontConfigure = true;
  enableParallelBuilding = true;
  hardeningDisable = [ "all" ];

  postPatch = ''
    patchShebangs chip util
    substituteInPlace util/getversion.sh \
      --replace-fail 'vbase="1.1.9999-''${ghash:0:7}"' 'vbase="v0.0.1-''${ghash:0:7}"'
  '';

  buildPhase = ''
    runHook preBuild

    VCSID=${rev} make BOARD=${board} CROSS_COMPILE=arm-none-eabi- out=build/${board}

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    install -Dm0644 build/${board}/ec.bin "$out/share/framework-ec/${board}/ec.bin"
    install -Dm0644 build/${board}/RO/ec.RO.flat "$out/share/framework-ec/${board}/ec.RO.flat"
    install -Dm0644 build/${board}/RW/ec.RW.flat "$out/share/framework-ec/${board}/ec.RW.flat"
    install -Dm0755 build/${board}/util/ectool "$out/bin/framework_ectool"

    runHook postInstall
  '';

  passthru = {
    inherit board supportsDisplayToggleKeyHid;
    imagePath = "share/framework-ec/${board}/ec.bin";
    rwImagePath = "share/framework-ec/${board}/ec.RW.flat";
  };

  meta = {
    description = "Framework Laptop embedded controller image";
    homepage = "https://github.com/FrameworkComputer/EmbeddedController";
    license = lib.licenses.bsd3;
    platforms = [ "x86_64-linux" ];
  };
}
