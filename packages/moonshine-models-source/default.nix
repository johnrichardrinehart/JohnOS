{
  fetchurl,
  lib,
  stdenvNoCC,
  baseUrl ? "https://download.moonshine.ai/model/medium-streaming-en/quantized",
  componentHashes ? {
    "adapter.ort" = "sha256-FjB0Qrf0Ip8vFRH8UbVFzslhblWHLFiPOil7vG9HYuo=";
    "cross_kv.ort" = "sha256-NUualVyut2i1KPRH8KNs5LhQyntFMZABZd8wTZeQT7o=";
    "decoder_kv.ort" = "sha256-+meqh1ISR/W/RNPkTU5JeOWMHxFCScPGkJyIJiQFZxU=";
    "decoder_kv_with_attention.ort" = "sha256-QJGd6V0IaQ2jqP9t8Uz1WzIgBG87dntKS3aeezKq8tI=";
    "encoder.ort" = "sha256-pfERZ6Yu72F4f+hBBFMlfW3bjrqQr0YalgTl8uk9UyI=";
    "frontend.ort" = "sha256-N4/opdcJChuauIu7H8lb3gEM3WTsI0GTUNLSPGdWNuk=";
    "streaming_config.json" = "sha256-KOg7eijpFHJpKgNeDa4xFkIq5DrrK+9e2CLETOibiK8=";
    "tokenizer.bin" = "sha256-aISzX9Y3fUxNMjNqC8FS82tk0eRbZQNoPNwjglCoRy0=";
  },
  modelArch ? 5,
  modelArchName ? "medium-streaming",
  modelName ? "medium-streaming-en",
}:

let
  modelArchMap = {
    tiny = 0;
    base = 1;
    "tiny-streaming" = 2;
    "base-streaming" = 3;
    "small-streaming" = 4;
    "medium-streaming" = 5;
  };

  fetchComponent =
    name: hash:
    fetchurl {
      inherit name hash;
      url = "${baseUrl}/${name}";
    };

  components = lib.mapAttrs fetchComponent componentHashes;
in
stdenvNoCC.mkDerivation {
  pname = "moonshine-models-source";
  version = "0.0.59";

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
  ''
  + lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: component: ''cp ${component} "$out/${name}"'') components
  )
  + ''

    runHook postInstall
  '';

  passthru = {
    inherit
      modelArch
      modelArchMap
      modelArchName
      modelName
      ;
  };

  meta = with lib; {
    description = "Moonshine medium streaming English quantized model components";
    homepage = "https://moonshine.ai";
    license = licenses.unfreeRedistributable;
    platforms = [ "x86_64-linux" ];
  };
}
