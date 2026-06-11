{
  pkgs,
  lib,
  model,
  modelArch ? 5,
  audioBackend ? "pulse",
  inputDevice ? null,
  leaderKey ? "KEY_RIGHTCTRL",
  startPhrase ? "start dictation",
  stopPhrase ? "stop dictation",
  moonshineVoice,
  shellcheck,
  coreutils,
  stdenv,
}:
let
  name = "whisper-voice-type";

  dictationLib = pkgs.writeTextFile {
    name = "dictation-lib";
    destination = "/dictation_lib.py";
    text = builtins.readFile ./dictation_lib.py;
  };

  python = pkgs.python3.withPackages (p: [
    moonshineVoice
    p.sounddevice
    p.numpy
    p.dbus-next
    p.evdev
  ]);

  pythonPath = "${dictationLib}";

  notify = lib.getExe' pkgs.libnotify "notify-send";
  pacat = "${pkgs.pulseaudio}/.bin-unwrapped/pacat";
  pactl = "${pkgs.pulseaudio}/.bin-unwrapped/pactl";
  wpctl = lib.getExe' pkgs.wireplumber "wpctl";
  wtype = lib.getExe pkgs.wtype;
  setsid = lib.getExe' pkgs.util-linux "setsid";

  script =
    (pkgs.writeScriptBin name (builtins.readFile ./whisper-voice-type.sh)).overrideAttrs
      (old: {
        buildCommand = "${old.buildCommand}\n patchShebangs $out";
      });

  runtimeInputs = [ coreutils ];
  wrapperArgs = [
    "--prefix"
    "PATH"
    ":"
    (lib.makeBinPath runtimeInputs)
    "--set"
    "DICTATION_LIB"
    pythonPath
    "--set"
    "MOONSHINE_MODEL_PATH"
    "${model}"
    "--set"
    "MOONSHINE_MODEL_ARCH"
    (toString modelArch)
    "--set"
    "MOONSHINE_AUDIO_BACKEND"
    audioBackend
    "--set"
    "MOONSHINE_START_PHRASE"
    startPhrase
    "--set"
    "MOONSHINE_STOP_PHRASE"
    stopPhrase
  ]
  ++ lib.optionals (inputDevice != null) [
    "--set"
    "MOONSHINE_INPUT_DEVICE"
    inputDevice
  ]
  ++ lib.optionals (leaderKey != null) [
    "--set"
    "MOONSHINE_LEADER_KEY"
    leaderKey
  ]
  ++ [
    "--set"
    "NOTIFY_SEND"
    notify
    "--set"
    "PACAT"
    pacat
    "--set"
    "PACTL"
    pactl
    "--set"
    "WPCTL"
    wpctl
    "--set"
    "WTYPE"
    wtype
    "--set"
    "SETSID"
    setsid
    "--set"
    "DAEMON_SCRIPT"
    "${./daemon.py}"
    "--set"
    "TRAIN_SCRIPT"
    "${./train.py}"
    "--set"
    "REVIEW_SCRIPT"
    "${./review.py}"
    "--set"
    "PYTHON"
    "${python}/bin/python3"
    "--set"
    "CLI_SCRIPT"
    "${./cli.py}"
  ];
in
stdenv.mkDerivation {
  inherit name;
  dontUnpack = true;

  nativeBuildInputs = [
    pkgs.makeWrapper
    shellcheck
  ];

  buildPhase = ''
    shellcheck ${./whisper-voice-type.sh}
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp ${script}/bin/${name} $out/bin/${name}
    wrapProgram $out/bin/${name} ${lib.escapeShellArgs wrapperArgs}
  '';

  meta = {
    description = "Voice dictation using Moonshine speech recognition";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = name;
  };
}
