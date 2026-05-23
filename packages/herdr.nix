{
  lib,
  bash,
  callPackage,
  coreutils,
  fetchFromGitHub,
  python3,
  rustPlatform,
  zig,
}:
rustPlatform.buildRustPackage rec {
  pname = "herdr";
  version = "0.6.0";

  src = fetchFromGitHub {
    owner = "ogulcancelik";
    repo = "herdr";
    tag = "v${version}";
    hash = "sha256-N0PRpWMpP2AqndgiN/Cw2/rTVhsrAFOIUZAH1BBvuwk=";
  };

  cargoHash = "sha256-k+MFTivVMO/jOi8OGYm0cHzmFiMLXyC4GlmEYAQD7To=";

  zigDeps = callPackage "${src}/vendor/libghostty-vt/build.zig.zon.nix" {
    name = "${pname}-${version}-zig-cache";
  };

  nativeBuildInputs = [
    zig
  ];

  nativeCheckInputs = [
    bash
    coreutils
    python3
  ];

  preBuild = ''
    export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-global-cache"
    export ZIG_LOCAL_CACHE_DIR="$TMPDIR/zig-local-cache"
    mkdir -p "$ZIG_GLOBAL_CACHE_DIR/p" "$ZIG_LOCAL_CACHE_DIR"
    cp -rL ${zigDeps}/* "$ZIG_GLOBAL_CACHE_DIR/p/"
  '';

  # portable-pty uses HOME as the cwd for spawned commands when no cwd is set.
  # Nix's default /homeless-shelter does not exist, which makes PTY
  # process-spawn tests fail with ENOENT before command lookup matters.
  preCheck = ''
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
  '';

  meta = {
    description = "Agent multiplexer that lives in your terminal";
    homepage = "https://github.com/ogulcancelik/herdr";
    license = lib.licenses.agpl3Plus;
    mainProgram = "herdr";
    maintainers = [ ];
  };
}
