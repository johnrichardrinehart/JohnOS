{
  autoPatchelfHook,
  lib,
  ffmpeg_7-full,
  fetchFromGitHub,
  fetchPypi,
  pkgs,
  perl,
  python3,
  stdenvNoCC,
}:
let
  runtimePython = python3.withPackages (
    ps:
    let
      gradio-rangeslider = ps.buildPythonPackage rec {
        pname = "gradio-rangeslider";
        version = "0.0.8";
        format = "wheel";

        src = fetchPypi {
          pname = "gradio_rangeslider";
          inherit version format;
          dist = "py3";
          python = "py3";
          hash = "sha256-NyjETljsG/8L3yNsyE8SsYP71Zb7RxTYt5dYWgUV+J4=";
        };

        propagatedBuildInputs = [ ps.gradio ];

        doCheck = false;
        pythonImportsCheck = [ "gradio_rangeslider" ];
      };
      onnxruntime-openvino = ps.buildPythonPackage rec {
        pname = "onnxruntime-openvino";
        version = "1.24.1";
        format = "wheel";

        src = fetchPypi {
          pname = "onnxruntime_openvino";
          inherit version format;
          dist = "cp313";
          python = "cp313";
          abi = "cp313";
          platform = "manylinux_2_28_x86_64";
          hash = "sha256-LDu3PmisJ/SJGvillcH69XTsaLdy5lg8kKC5l6GCJ4I=";
        };

        nativeBuildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [ autoPatchelfHook ];
        buildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [
          pkgs.ocl-icd
          pkgs.zlib
        ];

        dependencies = [
          ps.coloredlogs
          ps.numpy
          ps.packaging
        ];

        doCheck = false;
        pythonImportsCheck = [ "onnxruntime" ];
      };
    in
    [
      ps.gradio
      gradio-rangeslider
      ps.numpy
      ps.onnx
      onnxruntime-openvino
      ps.opencv4
      ps.psutil
      ps.scipy
      ps.tqdm
    ]
  );
in
stdenvNoCC.mkDerivation rec {
  pname = "facefusion";
  version = "3.5.2";

  src = fetchFromGitHub {
    owner = "facefusion";
    repo = "facefusion";
    rev = version;
    hash = "sha256-VvshApAQh9oMFjsQJPMlppFKURbc7SPOrRXOpVTFXZ8=";
  };

  nativeBuildInputs = [ perl ];

  installPhase = ''
    runHook preInstall

    perl -0pi -e 's/\t\t\t\t_, capture_frame = camera_capture.read\(\)\n\t\t\t\tif analyse_stream\(capture_frame, camera_fps\):/\t\t\t\tis_captured, capture_frame = camera_capture.read()\n\t\t\t\tif not is_captured or capture_frame is None:\n\t\t\t\t\tcontinue\n\t\t\t\tif analyse_stream(capture_frame, camera_fps):/' facefusion/streamer.py
    cat > facefusion/camera_manager.py <<'EOF'
from typing import List

import cv2

from facefusion.types import CameraPoolSet

CAMERA_POOL_SET : CameraPoolSet =\
{
	'capture': {}
}


def get_local_camera_capture(camera_id : int) -> cv2.VideoCapture:
	camera_key = str(camera_id)

	if camera_key not in CAMERA_POOL_SET.get('capture'):
		camera_capture = cv2.VideoCapture(camera_id, cv2.CAP_V4L2)

		if camera_capture.isOpened():
			CAMERA_POOL_SET['capture'][camera_key] = camera_capture

	return CAMERA_POOL_SET.get('capture').get(camera_key)


def get_remote_camera_capture(camera_url : str) -> cv2.VideoCapture:
	if camera_url not in CAMERA_POOL_SET.get('capture'):
		camera_capture = cv2.VideoCapture(camera_url)

		if camera_capture.isOpened():
			CAMERA_POOL_SET['capture'][camera_url] = camera_capture

	return CAMERA_POOL_SET.get('capture').get(camera_url)


def clear_camera_pool() -> None:
	for camera_capture in list(CAMERA_POOL_SET.get('capture').values()):
		camera_capture.release()

	CAMERA_POOL_SET['capture'].clear()


def detect_local_camera_ids(id_start : int, id_end : int) -> List[int]:
	local_camera_ids = []

	for camera_id in range(id_start, id_end):
		cv2.setLogLevel(0)
		camera_capture = get_local_camera_capture(camera_id)
		cv2.setLogLevel(3)

		if camera_capture and camera_capture.isOpened():
			local_camera_ids.append(camera_id)

	return local_camera_ids
EOF

    cat > facefusion/uis/components/webcam_options.py <<'EOF'
from pathlib import Path
from typing import Optional

import gradio

from facefusion import translator
from facefusion.camera_manager import detect_local_camera_ids
from facefusion.common_helper import get_first
from facefusion.uis import choices as uis_choices
from facefusion.uis.core import register_ui_component

WEBCAM_DEVICE_ID_DROPDOWN : Optional[gradio.Dropdown] = None
WEBCAM_MODE_RADIO : Optional[gradio.Radio] = None
WEBCAM_RESOLUTION_DROPDOWN : Optional[gradio.Dropdown] = None
WEBCAM_FPS_SLIDER : Optional[gradio.Slider] = None


def render() -> None:
	global WEBCAM_DEVICE_ID_DROPDOWN
	global WEBCAM_MODE_RADIO
	global WEBCAM_RESOLUTION_DROPDOWN
	global WEBCAM_FPS_SLIDER

	local_camera_ids = detect_local_camera_ids(0, 10) or [ 'none' ] #type:ignore[list-item]
	real_camera_ids = []

	for camera_id in local_camera_ids:
		device_name_path = Path(f'/sys/class/video4linux/video{camera_id}/name')

		if device_name_path.is_file() and not device_name_path.read_text().strip().startswith('Virtual Video'):
			real_camera_ids.append(camera_id)

	preferred_camera_ids = real_camera_ids or local_camera_ids
	WEBCAM_DEVICE_ID_DROPDOWN = gradio.Dropdown(
		value = get_first(preferred_camera_ids),
		label = translator.get('uis.webcam_device_id_dropdown'),
		choices = preferred_camera_ids
	)
	WEBCAM_MODE_RADIO = gradio.Radio(
		label = translator.get('uis.webcam_mode_radio'),
		choices = uis_choices.webcam_modes,
		value = uis_choices.webcam_modes[0]
	)
	WEBCAM_RESOLUTION_DROPDOWN = gradio.Dropdown(
		label = translator.get('uis.webcam_resolution_dropdown'),
		choices = uis_choices.webcam_resolutions,
		value = uis_choices.webcam_resolutions[0]
	)
	WEBCAM_FPS_SLIDER = gradio.Slider(
		label = translator.get('uis.webcam_fps_slider'),
		value = 30,
		step = 1,
		minimum = 1,
		maximum = 30
	)
	register_ui_component('webcam_device_id_dropdown', WEBCAM_DEVICE_ID_DROPDOWN)
	register_ui_component('webcam_mode_radio', WEBCAM_MODE_RADIO)
	register_ui_component('webcam_resolution_dropdown', WEBCAM_RESOLUTION_DROPDOWN)
	register_ui_component('webcam_fps_slider', WEBCAM_FPS_SLIDER)
EOF

    substituteInPlace facefusion.ini \
      --replace-fail 'execution_providers =' 'execution_providers = openvino cpu'

    mkdir -p $out/bin $out/share/facefusion
    cp -r facefusion $out/share/facefusion/
    cp facefusion.py facefusion.ini facefusion.ico $out/share/facefusion/
    mkdir -p $out/share/facefusion/.assets/models

cat > $out/bin/facefusion <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

data_dir="''${XDG_DATA_HOME:-$HOME/.local/share}/facefusion"
cache_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/facefusion"

mkdir -p "$data_dir"

if [ -d "$data_dir/facefusion" ]; then
  chmod -R u+w "$data_dir/facefusion" 2>/dev/null || true
  rm -rf "$data_dir/facefusion"
fi

if [ -f "$data_dir/facefusion.py" ]; then
  chmod u+w "$data_dir/facefusion.py" 2>/dev/null || true
fi

if [ -f "$data_dir/facefusion-entry.py" ]; then
  chmod u+w "$data_dir/facefusion-entry.py" 2>/dev/null || true
fi

if [ -f "$data_dir/facefusion.ico" ]; then
  chmod u+w "$data_dir/facefusion.ico" 2>/dev/null || true
fi

rm -rf "$data_dir/facefusion"
cp -r "@facefusionShare@/facefusion" "$data_dir/"
cp -f "@facefusionShare@/facefusion.py" "$data_dir/facefusion-entry.py"
cp -f "@facefusionShare@/facefusion.ico" "$data_dir/"
chmod -R u+w "$data_dir/facefusion" 2>/dev/null || true
chmod u+w "$data_dir/facefusion-entry.py" "$data_dir/facefusion.ico" 2>/dev/null || true

if [ ! -e "$data_dir/facefusion.ini" ]; then
  cp -f "@facefusionShare@/facefusion.ini" "$data_dir/"
fi

if grep -Eq '^execution_providers[[:space:]]*=[[:space:]]*$' "$data_dir/facefusion.ini"; then
  sed -i 's/^execution_providers[[:space:]]*=.*/execution_providers = openvino cpu/' "$data_dir/facefusion.ini"
fi

default_output_video_encoder='libx264'
if [ -c /dev/dri/renderD128 ] || [ -c /dev/dri/renderD129 ]; then
  default_output_video_encoder='h264_qsv'
fi

if grep -Eq '^output_video_encoder[[:space:]]*=[[:space:]]*$' "$data_dir/facefusion.ini"; then
  sed -i "s/^output_video_encoder[[:space:]]*=.*/output_video_encoder = $default_output_video_encoder/" "$data_dir/facefusion.ini"
fi

mkdir -p "$cache_dir/models"
mkdir -p "$data_dir/.assets"
chmod u+w "$data_dir" "$data_dir/.assets" 2>/dev/null || true

if [ -d "$data_dir/.assets/models" ] && [ ! -L "$data_dir/.assets/models" ]; then
  chmod -R u+w "$data_dir/.assets/models" 2>/dev/null || true
  rm -rf "$data_dir/.assets/models"
fi

if [ -L "$data_dir/.assets/models" ]; then
  rm -f "$data_dir/.assets/models"
fi

if [ ! -e "$data_dir/.assets/models" ]; then
  ln -s "$cache_dir/models" "$data_dir/.assets/models"
fi

export PATH='@ffmpegPath@':"$PATH"
export PYTHONPATH="$data_dir:@pythonSitePath@"

cd "$data_dir"
exec @pythonBin@ "$data_dir/facefusion-entry.py" "$@"
EOF

    substituteInPlace $out/bin/facefusion \
      --replace-fail @facefusionShare@ "$out/share/facefusion" \
      --replace-fail @ffmpegPath@ "${lib.makeBinPath [ ffmpeg_7-full ]}" \
      --replace-fail @pythonBin@ "${runtimePython}/bin/python" \
      --replace-fail @pythonSitePath@ "${runtimePython}/${python3.sitePackages}"

    chmod +x $out/bin/facefusion

    runHook postInstall
  '';

  meta = with lib; {
    description = "Webcam deepfake and face swap application";
    homepage = "https://github.com/facefusion/facefusion";
    license = licenses.unfree;
    mainProgram = "facefusion";
    maintainers = [ ];
    platforms = platforms.linux;
  };
}
