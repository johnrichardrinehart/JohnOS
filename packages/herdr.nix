{ lib
, bash
, callPackage
, coreutils
, fetchFromGitHub
, python3
, rustPlatform
, zig
,
}:
rustPlatform.buildRustPackage rec {
  pname = "herdr";
  version = "0.5.7";

  src = fetchFromGitHub {
    owner = "ogulcancelik";
    repo = "herdr";
    tag = "v${version}";
    hash = "sha256-IuJaOPSCYydzI0iNOGX5qgIxOjH3QT4TCvx8en4uci8=";
  };

  cargoHash = "sha256-4yu0ScVMgOK8E1LtG6pQCqV4Dq6gfVj80i0Bg9kGoW4=";

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
