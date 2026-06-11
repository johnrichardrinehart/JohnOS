{
  lib,
  onnxruntime,
  openvino,
}:

(onnxruntime.override {
  pythonSupport = false;
}).overrideAttrs
  (old: {
    buildInputs = old.buildInputs ++ [ openvino ];
    cmakeFlags = old.cmakeFlags ++ [
      (lib.cmakeBool "onnxruntime_USE_OPENVINO" true)
      (lib.cmakeBool "onnxruntime_DISABLE_RTTI" false)
      (lib.cmakeBool "onnxruntime_BUILD_UNIT_TESTS" false)
      "-DOpenVINO_DIR=${openvino}/runtime/cmake"
    ];
    postFixup = (old.postFixup or "") + ''
      patchelf --add-rpath ${openvino}/runtime/lib/intel64 $out/lib/libonnxruntime_providers_openvino.so
    '';
  })
