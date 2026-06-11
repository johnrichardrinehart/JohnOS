# Convert Moonshine .ort models to FP32 .onnx for OpenVINO EP compatibility.
#
# Pipeline: .ort flatbuffer → .onnx protobuf (via ORT) → dequantize contrib ops
# to standard ONNX (DynamicQuantizeMatMul → MatMul, FusedMatMul → MatMul, etc.)
{
  lib,
  stdenvNoCC,
  python3,
  modelDir,
}:
let
  python = python3.withPackages (ps: [
    ps.onnxruntime
    ps.onnx
    ps.numpy
  ]);

  dequantizeScript = ../scripts/dequantize-moonshine.py;

  convertScript = ''
    import onnxruntime as ort
    import os, sys, shutil

    model_dir = sys.argv[1]
    out_dir = sys.argv[2]

    os.makedirs(out_dir, exist_ok=True)

    models = ["frontend", "encoder", "adapter", "cross_kv", "decoder_kv",
              "decoder_kv_with_attention"]

    for name in models:
        ort_path = os.path.join(model_dir, f"{name}.ort")
        onnx_path = os.path.join(out_dir, f"{name}.onnx")

        if not os.path.exists(ort_path):
            continue

        print(f"Converting {name}.ort -> {name}.onnx ...")
        so = ort.SessionOptions()
        so.optimized_model_filepath = onnx_path
        so.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_BASIC
        ort.InferenceSession(ort_path, so)
        size_mb = os.path.getsize(onnx_path) / 1024 / 1024
        print(f"  {name}.onnx: {size_mb:.1f} MB")

    # Copy non-model files
    for f in os.listdir(model_dir):
        if not f.endswith(".ort"):
            src = os.path.join(model_dir, f)
            dst = os.path.join(out_dir, f)
            if os.path.isfile(src) and not os.path.exists(dst):
                shutil.copy2(src, dst)
                print(f"Copied {f}")
  '';
in
stdenvNoCC.mkDerivation {
  pname = "moonshine-models-onnx";
  version = "0.0.59";

  dontUnpack = true;

  nativeBuildInputs = [ python ];

  buildPhase = ''
    runHook preBuild

    # Step 0: Reassemble split .ort files (chunks named foo.ort.0, foo.ort.1, …)
    cp -r "${modelDir}" "$TMPDIR/models"
    chmod -R u+w "$TMPDIR/models"
    for base in "$TMPDIR/models"/*.ort.0; do
      [ -f "$base" ] || continue
      name="''${base%.0}"
      cat $(printf '%s\n' "$name".* | sort -V) > "$name"
      rm "$name".*
    done

    # Step 1: Convert .ort flatbuffer → .onnx protobuf
    ${python}/bin/python3 -c ${lib.escapeShellArg convertScript} "$TMPDIR/models" "$TMPDIR/quantized"

    # Step 2: Dequantize contrib ops to standard FP32 ONNX
    ${python}/bin/python3 ${dequantizeScript} "$TMPDIR/quantized" "$TMPDIR/out"

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    cp -r "$TMPDIR/out" "$out"
    runHook postInstall
  '';

  meta = {
    description = "Moonshine Voice FP32 ONNX models for OpenVINO EP (dequantized from upstream .ort)";
    platforms = [ "x86_64-linux" ];
  };
}
