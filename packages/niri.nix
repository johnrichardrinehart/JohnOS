{
  lib,
  rustPlatform,
  fetchFromGitHub,
  installShellFiles,
  pkg-config,
  dbus,
  libdisplay-info,
  libglvnd,
  libinput,
  libxkbcommon,
  libgbm,
  pango,
  pipewire,
  seatd,
  systemd,
  wayland,
}:

rustPlatform.buildRustPackage rec {
  pname = "niri";
  version = "26.04";

  src = fetchFromGitHub {
    owner = "niri-wm";
    repo = "niri";
    rev = "v${version}";
    hash = "sha256-ehSMsSpE+0k8r+2Vseu8kangsYxToZv3vinynsDp9zs=";
  };

  cargoLock = {
    allowBuiltinFetchGit = true;
    lockFile = "${src}/Cargo.lock";
  };

  postPatch = ''
    patchShebangs resources/niri-session
    substituteInPlace resources/niri.service \
      --replace-fail 'ExecStart=niri' "ExecStart=$out/bin/niri"
  '';

  nativeBuildInputs = [
    installShellFiles
    pkg-config
    rustPlatform.bindgenHook
  ];

  buildInputs = [
    dbus
    libdisplay-info
    libglvnd
    libinput
    libxkbcommon
    libgbm
    pango
    pipewire
    seatd
    systemd
    wayland
  ];

  buildFeatures = [
    "dbus"
    "xdp-gnome-screencast"
    "systemd"
  ];
  buildNoDefaultFeatures = true;

  checkFlags = [ "--skip=::egl" ];

  postInstall = ''
    install -Dm0644 resources/niri.desktop -t $out/share/wayland-sessions
    install -Dm0644 resources/niri-portals.conf -t $out/share/xdg-desktop-portal
    install -Dm0755 resources/niri-session -t $out/bin
    install -Dm0644 resources/niri{-shutdown.target,.service} -t $out/lib/systemd/user
  '';

  RUSTFLAGS = toString (
    map (arg: "-C link-arg=" + arg) [
      "-Wl,--push-state,--no-as-needed"
      "-lEGL"
      "-lwayland-client"
      "-Wl,--pop-state"
    ]
  );

  NIRI_BUILD_COMMIT = "v${version}";

  passthru.providedSessions = [ "niri" ];

  meta = {
    description = "A scrollable-tiling Wayland compositor";
    homepage = "https://github.com/niri-wm/niri";
    license = lib.licenses.gpl3Only;
    mainProgram = "niri";
    maintainers = with lib.maintainers; [ johnrichardrinehart ];
    platforms = lib.platforms.linux;
  };
}
