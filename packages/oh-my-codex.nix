{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  makeWrapper,
  nodejs,
  rustPlatform,
  stdenv,
}:
let
  pname = "oh-my-codex";
  version = "unstable-2026-04-20";
  rev = "da0c779c4a81016d51201cb11f4a2274192e9c71";

  src = fetchFromGitHub {
    owner = "johnrichardrinehart";
    repo = "oh-my-codex";
    inherit rev;
    hash = "sha256-u/RWNtybhYS8qP+Ntig9IeDsDtdvrAAZpmbkan7tGAI=";
  };

  nodePlatform =
    if stdenv.hostPlatform.isLinux then
      "linux"
    else if stdenv.hostPlatform.isDarwin then
      "darwin"
    else
      throw "oh-my-codex is only packaged for Linux and Darwin";

  nodeArch =
    if stdenv.hostPlatform.parsed.cpu.name == "x86_64" then
      "x64"
    else if stdenv.hostPlatform.parsed.cpu.name == "aarch64" then
      "arm64"
    else
      throw "Unsupported CPU architecture for oh-my-codex";

  sparkshellPlatformKey = "${nodePlatform}-${nodeArch}";
  exploreBinary = "omx-explore-harness";
  sparkshellBinary = "omx-sparkshell";

  exploreHarness = rustPlatform.buildRustPackage {
    pname = "omx-explore-harness";
    inherit version src;

    cargoLock.lockFile = "${src}/Cargo.lock";
    cargoBuildFlags = [ "-p" "omx-explore-harness" ];
    doCheck = false;
  };

  sparkshell = rustPlatform.buildRustPackage {
    pname = "omx-sparkshell";
    inherit version src;

    cargoLock.lockFile = "${src}/Cargo.lock";
    cargoBuildFlags = [ "-p" "omx-sparkshell" ];
    doCheck = false;
  };
in
buildNpmPackage {
  inherit pname version src;

  npmDepsHash = "sha256-cL/mooHqQs6BS94PiilNbQGUr4qMLdA3xJyO08jawTA=";

  nativeBuildInputs = [ makeWrapper ];

  npmBuildScript = "build";

  installPhase = ''
    runHook preInstall

    export HOME="$TMPDIR"
    npm prune --omit=dev --ignore-scripts

    pkgRoot="$out/lib/${pname}"
    mkdir -p "$pkgRoot" "$out/bin" "$pkgRoot/bin/native/${sparkshellPlatformKey}" "$pkgRoot/src"

    cp package.json package-lock.json Cargo.toml Cargo.lock README.md "$pkgRoot/"
    cp -r dist crates prompts skills templates "$pkgRoot/"
    cp -r src/scripts "$pkgRoot/src/"
    cp -r node_modules "$pkgRoot/"

    install -m755 "${exploreHarness}/bin/${exploreBinary}" "$pkgRoot/bin/${exploreBinary}"
    install -m755 "${sparkshell}/bin/${sparkshellBinary}" \
      "$pkgRoot/bin/native/${sparkshellPlatformKey}/${sparkshellBinary}"

    cat > "$pkgRoot/bin/omx-explore-harness.meta.json" <<EOF
    {
      "binaryName": "${exploreBinary}",
      "platform": "${nodePlatform}",
      "arch": "${nodeArch}",
      "strategy": "nix-packaged"
    }
    EOF

    makeWrapper ${nodejs}/bin/node "$out/bin/omx" \
      --prefix PATH : ${lib.escapeShellArg (lib.makeBinPath [ nodejs ])} \
      --add-flags "$pkgRoot/dist/cli/omx.js"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Multi-agent orchestration layer for OpenAI Codex CLI";
    homepage = "https://github.com/johnrichardrinehart/oh-my-codex";
    license = licenses.mit;
    mainProgram = "omx";
    platforms = platforms.linux ++ platforms.darwin;
    maintainers = [ ];
  };
}
