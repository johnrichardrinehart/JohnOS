# moonshine-voice Python package using our custom libmoonshine.so
# built with OpenVINO GPU support.
{
  lib,
  python3,
  fetchurl,
  autoPatchelfHook,
  stdenv,
  libmoonshine,
  onnxruntime,
}:
let
  pname = "moonshine-voice";
  version = "0.0.59";

  wheel = fetchurl {
    url = "https://files.pythonhosted.org/packages/7d/f7/84140df51fa82cf582e888ac7e7a57e94639bd8fa2e47a831ba93c39ebc7/moonshine_voice-${version}-py3-none-manylinux_2_34_x86_64.whl";
    sha256 = "631f3fc4bc1ea98ed921a8387d916fa674b60649cfaf869d94d18f1393e192e6";
  };
in
python3.pkgs.buildPythonPackage {
  inherit pname version;
  format = "wheel";

  src = wheel;

  nativeBuildInputs = [
    autoPatchelfHook
  ];

  buildInputs = [
    stdenv.cc.cc.lib # libstdc++
  ];

  propagatedBuildInputs = with python3.pkgs; [
    numpy
    sounddevice
    requests
    tqdm
    filelock
    platformdirs
  ];

  # Replace the bundled native libs with our GPU-enabled build.
  postInstall = ''
    site=$out/${python3.sitePackages}

    # Replace bundled libmoonshine.so with our OpenVINO-enabled build
    rm -f $site/moonshine_voice/libmoonshine.so
    ln -s ${libmoonshine}/lib/libmoonshine.so $site/moonshine_voice/libmoonshine.so

    # Replace bundled libonnxruntime with the system one (has OpenVINO EP)
    rm -f $site/moonshine_voice.libs/libonnxruntime*.so*
    ln -s ${onnxruntime}/lib/libonnxruntime.so $site/moonshine_voice.libs/libonnxruntime.so.1

    # Also remove the bundled macOS dylibs
    rm -f $site/moonshine_voice/libmoonshine.dylib
    rm -f $site/moonshine_voice/libonnxruntime*.dylib

    # Performance: _parse_transcript runs on every update_transcription (~10/s)
    # and rebuilds every accumulated line. Per line it copies the raw audio
    # samples out of C one element at a time via ctypes (audio_data =
    # list(audio_array)) plus per-word timing structs. That cost grows with the
    # transcript, so a long session falls behind real time and dictation lags.
    # Our consumer reads only line.text and the boolean flags, so skip both
    # copies (audio_data and words stay None).
    substituteInPlace $site/moonshine_voice/transcriber.py \
      --replace-fail \
        'if line_c.audio_data and line_c.audio_data_count > 0:' \
        'if False:  # JohnOS: skip unused audio_data copy (O(samples)/line/update)' \
      --replace-fail \
        'if line_c.words and line_c.word_count > 0:' \
        'if False:  # JohnOS: skip unused per-word timing copy'
  '';

  pythonImportsCheck = [ "moonshine_voice" ];

  meta = {
    description = "Fast, accurate, on-device AI voice library with OpenVINO GPU support";
    homepage = "https://moonshine.ai";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}
