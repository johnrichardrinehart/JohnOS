# Build libmoonshine.so from source with configurable ONNX Runtime execution providers.
#
# The upstream code creates ORT sessions using CPU EP only. We patch
# moonshine-model.cpp and moonshine-streaming-model.cpp to optionally
# append the OpenVINO EP before session creation.
{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  ninja,
  onnxruntime,
  openvino,
  autoAddDriverRunpath,
  useOpenVINO ? true,
  useOnnxModels ? useOpenVINO,
  executionProviders ? {
    audio = {
      provider = "openvino";
      device = "GPU";
      precision = "FP16";
    };
    decoder = {
      provider = "openvino";
      device = "GPU";
      precision = "FP16";
    };
  },
}:
let
  providerNames = [
    "cpu"
    "openvino"
  ];
  normalizeProvider =
    fallback: provider:
    fallback
    // provider
    // {
      provider = provider.provider or fallback.provider;
      device = provider.device or fallback.device;
      precision = provider.precision or fallback.precision;
    };
  defaultOpenVINO = {
    provider = "openvino";
    device = "GPU";
    precision = "FP16";
  };
  audioProvider = normalizeProvider defaultOpenVINO (executionProviders.audio or { });
  decoderProvider = normalizeProvider defaultOpenVINO (executionProviders.decoder or { });
  usesOpenVINO = audioProvider.provider == "openvino" || decoderProvider.provider == "openvino";
  cString = builtins.toJSON;
  audioOptionsExpr =
    if audioProvider.provider == "openvino" then
      "make_openvino_options(${cString audioProvider.device}, ${cString audioProvider.precision}, reshape_input)"
    else
      "make_cpu_options()";
  decoderOptionsExpr =
    if decoderProvider.provider == "openvino" then
      "make_openvino_options(${cString decoderProvider.device}, ${cString decoderProvider.precision}, nullptr)"
    else
      "make_cpu_options()";
in
assert lib.assertMsg (builtins.elem audioProvider.provider providerNames)
  "libmoonshine executionProviders.audio.provider must be one of: ${lib.concatStringsSep ", " providerNames}";
assert lib.assertMsg (builtins.elem decoderProvider.provider providerNames)
  "libmoonshine executionProviders.decoder.provider must be one of: ${lib.concatStringsSep ", " providerNames}";
stdenv.mkDerivation {
  pname = "libmoonshine";
  version = "0.0.59";

  src = fetchFromGitHub {
    owner = "moonshine-ai";
    repo = "moonshine";
    tag = "v0.0.59";
    hash = "sha256-lEek4275OMtVpMstl1NXfUPPV8SJQwUdRa6LKhuYGfY=";
  };

  sourceRoot = "source/core";

  nativeBuildInputs = [
    cmake
    ninja
    autoAddDriverRunpath
  ];

  buildInputs = [
    onnxruntime
  ]
  ++ lib.optionals usesOpenVINO [
    openvino
  ];

  cmakeFlags = [
    "-DONNXRUNTIME_LIB_PATH=${onnxruntime}/lib/libonnxruntime.so"
    "-DCMAKE_BUILD_WITH_INSTALL_RPATH=ON"
    "-DCMAKE_INSTALL_RPATH=${onnxruntime}/lib"
  ];

  env.NIX_CFLAGS_COMPILE = "-Wno-error=unused-result -Wno-error=array-bounds";

  postPatch = ''
    # Replace bundled ORT headers with system ones
    rm -rf third-party/onnxruntime/include
    mkdir -p third-party/onnxruntime/include
    for h in ${onnxruntime.dev}/include/onnxruntime/*.h; do
      ln -s "$h" third-party/onnxruntime/include/
    done

    # Replace bundled ORT library with system one
    rm -rf third-party/onnxruntime/lib
    mkdir -p third-party/onnxruntime/lib/linux/x86_64
    ln -s ${onnxruntime}/lib/libonnxruntime.so third-party/onnxruntime/lib/linux/x86_64/libonnxruntime.so.1
  ''
  + lib.optionalString useOnnxModels ''
        # Load .onnx models instead of .ort so OpenVINO EP can process the graphs.
        sed -i 's/frontend\.ort/frontend.onnx/g; s/encoder\.ort/encoder.onnx/g; s/adapter\.ort/adapter.onnx/g; s/cross_kv\.ort/cross_kv.onnx/g; s/decoder_kv\.ort/decoder_kv.onnx/g; s/decoder_kv_with_attention\.ort/decoder_kv_with_attention.onnx/g' \
          moonshine-streaming-model.cpp

        # Add <thread> include for deferred decoder loading.
        sed -i '/#include "moonshine-streaming-model.h"/a #include <thread>' \
          moonshine-streaming-model.cpp

        # NOTE: provider-specific options are NOT appended to the shared
        # ort_session_options here. OpenVINO's dynamic-shape reshape_input is
        # per-input-name and model->reshape() throws on names absent from a
        # given model, so each model needs its own SessionOptions.

        # Add decoder_loader_thread member to the struct.
        sed -i '/#include <mutex>/a #include <thread>' moonshine-streaming-model.h
        sed -i '/std::mutex processing_mutex;/a \
        std::thread decoder_loader_thread; \
        int decoder_load_result = 0;' moonshine-streaming-model.h

        # Join decoder loader thread in destructor before releasing sessions.
        sed -i '/MoonshineStreamingModel::~MoonshineStreamingModel/,/^}/ {
          /ort_api->ReleaseEnv/i \
        if (decoder_loader_thread.joinable()) decoder_loader_thread.join();
        }' moonshine-streaming-model.cpp

        # Wait for decoder models in compute_cross_kv before using them.
        sed -i '/if (state == nullptr || cross_kv_session == nullptr)/i \
        if (decoder_loader_thread.joinable()) { \
          decoder_loader_thread.join(); \
          if (decoder_load_result != 0) return decoder_load_result; \
        }' moonshine-streaming-model.cpp

        # Load audio pipeline models synchronously, decoder models in background.
        #
        # Each model gets its OWN SessionOptions. The audio pipeline gets
        # bounded reshape_input values because OpenVINO refuses unbounded
        # dynamic shapes on GPU. Decoder provider/device are configurable: some
        # systems prefer GPU, others prefer ORT CPU or OpenVINO CPU.
        cat > deferred_load.cpp.fragment <<'FRAGMENT'
      // Build an OpenVINO SessionOptions for one model. reshape_input may be
      // null for providers/devices where the graph should not be reshaped.
      // Returns nullptr on failure; caller falls back to the shared CPU options.
      auto make_openvino_options = [this](const char *device, const char *precision, const char *reshape_input) -> OrtSessionOptions * {
        static std::string ov_cache_dir;
        if (ov_cache_dir.empty()) {
          const char *xdg = getenv("XDG_CACHE_HOME");
          const char *home = getenv("HOME");
          if (xdg) ov_cache_dir = std::string(xdg) + "/moonshine-openvino";
          else if (home) ov_cache_dir = std::string(home) + "/.cache/moonshine-openvino";
          else ov_cache_dir = "/tmp/moonshine-openvino";
        }
        OrtSessionOptions *opts = nullptr;
        if (ort_api->CreateSessionOptions(&opts) != nullptr || opts == nullptr) return nullptr;
        OrtStatus *graph_opt_status = ort_api->SetSessionGraphOptimizationLevel(opts, ORT_ENABLE_ALL);
        if (graph_opt_status != nullptr) {
          LOG_ORT_ERROR(ort_api, graph_opt_status);
          ort_api->ReleaseSessionOptions(opts);
          return nullptr;
        }
        const char *keys_with_shape[] = {"device_type", "precision", "cache_dir", "reshape_input"};
        const char *vals_with_shape[] = {device, precision, ov_cache_dir.c_str(), reshape_input};
        const char *keys_without_shape[] = {"device_type", "precision", "cache_dir"};
        const char *vals_without_shape[] = {device, precision, ov_cache_dir.c_str()};
        OrtStatus *st = ort_api->SessionOptionsAppendExecutionProvider_OpenVINO_V2(
            opts,
            reshape_input ? keys_with_shape : keys_without_shape,
            reshape_input ? vals_with_shape : vals_without_shape,
            reshape_input ? 4 : 3);
        if (st != nullptr) {
          LOG_ORT_ERROR(ort_api, st);
          ort_api->ReleaseSessionOptions(opts);
          return nullptr;
        }
        return opts;
      };

      // Build plain ORT CPU SessionOptions.
      [[maybe_unused]] auto make_cpu_options = [this]() -> OrtSessionOptions * {
        OrtSessionOptions *opts = nullptr;
        if (ort_api->CreateSessionOptions(&opts) != nullptr || opts == nullptr) return nullptr;
        OrtStatus *graph_opt_status = ort_api->SetSessionGraphOptimizationLevel(opts, ORT_ENABLE_ALL);
        if (graph_opt_status != nullptr) {
          LOG_ORT_ERROR(ort_api, graph_opt_status);
          ort_api->ReleaseSessionOptions(opts);
          return nullptr;
        }
        return opts;
      };

      auto make_audio_options = [&](const char *reshape_input) -> OrtSessionOptions * {
        return ${audioOptionsExpr};
      };
      auto make_decoder_options = [&]() -> OrtSessionOptions * {
        return ${decoderOptionsExpr};
      };

      OrtSessionOptions *frontend_opts = make_audio_options("audio_chunk[1,1280]");
      OrtSessionOptions *encoder_opts  = make_audio_options("features[1,1..1500,768]");
      OrtSessionOptions *adapter_opts  = make_audio_options("encoded[1,1..1500,768]");
      if (frontend_opts == nullptr) frontend_opts = ort_session_options;
      if (encoder_opts == nullptr)  encoder_opts  = ort_session_options;
      if (adapter_opts == nullptr)  adapter_opts  = ort_session_options;

      // Load audio pipeline models (frontend, encoder, adapter) synchronously.
      RETURN_ON_ERROR(ort_session_from_path(
          ort_api, ort_env, frontend_opts, frontend_path.c_str(),
          &frontend_session, &frontend_mmapped_data, &frontend_mmapped_data_size));
      RETURN_ON_NULL(frontend_session);

      RETURN_ON_ERROR(ort_session_from_path(
          ort_api, ort_env, encoder_opts, encoder_path.c_str(),
          &encoder_session, &encoder_mmapped_data, &encoder_mmapped_data_size));
      RETURN_ON_NULL(encoder_session);

      RETURN_ON_ERROR(ort_session_from_path(
          ort_api, ort_env, adapter_opts, adapter_path.c_str(),
          &adapter_session, &adapter_mmapped_data, &adapter_mmapped_data_size));
      RETURN_ON_NULL(adapter_session);

      if (frontend_opts != ort_session_options) ort_api->ReleaseSessionOptions(frontend_opts);
      if (encoder_opts != ort_session_options)  ort_api->ReleaseSessionOptions(encoder_opts);
      if (adapter_opts != ort_session_options)  ort_api->ReleaseSessionOptions(adapter_opts);

      // Load decoder models (cross_kv, decoder_kv) in background thread.
      // They're only needed at first decode step, not for audio capture.
      {
        std::string cross_kv_path = append_path_component(model_dir, "cross_kv.onnx");
        std::string decoder_kv_path = append_path_component(model_dir, "decoder_kv.onnx");
        decoder_loader_thread = std::thread([this, cross_kv_path, decoder_kv_path, make_decoder_options]() {
          OrtSessionOptions *cross_kv_opts = make_decoder_options();
          OrtSessionOptions *decoder_kv_opts = make_decoder_options();
          if (cross_kv_opts == nullptr) cross_kv_opts = ort_session_options;
          if (decoder_kv_opts == nullptr) decoder_kv_opts = ort_session_options;
          const char *ck_mmap = nullptr; size_t ck_mmap_sz = 0;
          const char *dk_mmap = nullptr; size_t dk_mmap_sz = 0;
          int r1 = ort_session_from_path(ort_api, ort_env, cross_kv_opts,
              cross_kv_path.c_str(), &cross_kv_session, &ck_mmap, &ck_mmap_sz);
          int r2 = ort_session_from_path(ort_api, ort_env, decoder_kv_opts,
              decoder_kv_path.c_str(), &decoder_kv_session, &dk_mmap, &dk_mmap_sz);
          if (cross_kv_opts != ort_session_options) ort_api->ReleaseSessionOptions(cross_kv_opts);
          if (decoder_kv_opts != ort_session_options) ort_api->ReleaseSessionOptions(decoder_kv_opts);
          decoder_load_result = (r1 != 0 || r2 != 0 || !cross_kv_session || !decoder_kv_session) ? -1 : 0;
        });
      }
    FRAGMENT

        # Delete the sequential load block and replace with deferred version.
        sed -i '/\/\/ Load sessions using ort_session_from_path/,/\/\/ Load tokenizer/{
          /\/\/ Load tokenizer/!{
            /\/\/ Load sessions using ort_session_from_path/{
              r deferred_load.cpp.fragment
            }
            d
          }
        }' moonshine-streaming-model.cpp
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 libmoonshine.so $out/lib/libmoonshine.so
    install -Dm644 ../moonshine-c-api.h $out/include/moonshine-c-api.h
    runHook postInstall
  '';

  meta = {
    description = "Moonshine Voice native inference library with OpenVINO GPU support";
    homepage = "https://github.com/moonshine-ai/moonshine";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}
