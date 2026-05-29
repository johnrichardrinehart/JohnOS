{
  lib,
  callPackage,
  fetchFromGitHub,
  rustPlatform,
  zig_0_15,
}:
rustPlatform.buildRustPackage rec {
  pname = "herdr";
  version = "0.6.4";

  src = fetchFromGitHub {
    owner = "ogulcancelik";
    repo = "herdr";
    tag = "v${version}";
    hash = "sha256-bf1sVfGgfqpQYTRU2m0K/o2HEq5DV3R7nW5Lgll3+wI=";
  };

  cargoHash = "sha256-yRT31RnfjSQy5bxFXVvM9zRM59WAPrBozu3S2tag6s8=";

  zigDeps = callPackage "${src}/vendor/libghostty-vt/build.zig.zon.nix" {
    name = "${pname}-${version}-zig-cache";
  };

  preBuild = ''
    # Keep zig out of nativeBuildInputs: its setup hook selects `zig build`,
    # while herdr is a Cargo project that only needs Zig 0.15 during build scripts.
    export PATH="${lib.getBin zig_0_15}/bin:$PATH"
    export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-global-cache"
    export ZIG_LOCAL_CACHE_DIR="$TMPDIR/zig-local-cache"
    mkdir -p "$ZIG_GLOBAL_CACHE_DIR/p" "$ZIG_LOCAL_CACHE_DIR"
    cp -rL ${zigDeps}/* "$ZIG_GLOBAL_CACHE_DIR/p/"
  '';

  # The upstream test suite includes real PTY/foreground-process integration
  # tests that can hang under the remote Nix builder.
  doCheck = false;

  meta = {
    description = "Agent multiplexer that lives in your terminal";
    homepage = "https://github.com/ogulcancelik/herdr";
    license = lib.licenses.agpl3Plus;
    mainProgram = "herdr";
    maintainers = [ ];
  };
}
