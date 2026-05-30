{
  lib,
  stdenvNoCC,
  python3,
}:

stdenvNoCC.mkDerivation {
  pname = "legacy-network-configs";
  version = "0.1.0";

  src = ./.;
  outputs = [
    "out"
    "toIwd"
    "toNetworkManager"
  ];

  dontBuild = true;
  doCheck = true;

  checkPhase = ''
    runHook preCheck

    ${python3}/bin/python3 tests/test_roundtrip.py

    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall

    install -Dm755 legacy-network-config-to-iwd.py "$out/bin/legacy-network-config-to-iwd"
    install -Dm755 legacy-network-configs-to-nm.py "$out/bin/legacy-network-configs-to-nm"
    install -Dm644 wifi_profile_convert.py "$out/bin/wifi_profile_convert.py"
    substituteInPlace "$out/bin/legacy-network-config-to-iwd" \
      --replace-fail "/usr/bin/env python3" "${python3}/bin/python3"
    substituteInPlace "$out/bin/legacy-network-configs-to-nm" \
      --replace-fail "/usr/bin/env python3" "${python3}/bin/python3"

    install -Dm755 legacy-network-config-to-iwd.py "$toIwd/bin/legacy-network-config-to-iwd"
    install -Dm644 wifi_profile_convert.py "$toIwd/bin/wifi_profile_convert.py"
    substituteInPlace "$toIwd/bin/legacy-network-config-to-iwd" \
      --replace-fail "/usr/bin/env python3" "${python3}/bin/python3"

    install -Dm755 legacy-network-configs-to-nm.py "$toNetworkManager/bin/legacy-network-configs-to-nm"
    install -Dm644 wifi_profile_convert.py "$toNetworkManager/bin/wifi_profile_convert.py"
    substituteInPlace "$toNetworkManager/bin/legacy-network-configs-to-nm" \
      --replace-fail "/usr/bin/env python3" "${python3}/bin/python3"

    runHook postInstall
  '';

  meta = {
    description = "Import legacy Wi-Fi manager profiles into the selected manager";
    license = lib.licenses.mit;
    mainProgram = "legacy-network-config-to-iwd";
    platforms = lib.platforms.linux;
  };
}
