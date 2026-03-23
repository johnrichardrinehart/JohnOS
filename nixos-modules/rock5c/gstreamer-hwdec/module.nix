{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dev.johnrinehart.rock5c.gstreamerHwdec;

  gstPackages = [
    pkgs.gst_all_1.gstreamer
    pkgs.gst_all_1.gst-plugins-base
    pkgs.gst_all_1.gst-plugins-good
    pkgs.gst_all_1.gst-plugins-bad
    pkgs.v4l-utils
  ];

  gstPluginPath = lib.concatStringsSep ":" [
    "${lib.getLib pkgs.gst_all_1.gstreamer}/lib/gstreamer-1.0"
    "${lib.getLib pkgs.gst_all_1.gst-plugins-base}/lib/gstreamer-1.0"
    "${lib.getLib pkgs.gst_all_1.gst-plugins-good}/lib/gstreamer-1.0"
    "${lib.getLib pkgs.gst_all_1.gst-plugins-bad}/lib/gstreamer-1.0"
  ];

  gstBinPath = lib.makeBinPath gstPackages;

  gstLaunch = pkgs.writeShellApplication {
    name = "rock5c-gst-launch";
    runtimeInputs = gstPackages;
    text = ''
      export GST_PLUGIN_SYSTEM_PATH_1_0="${gstPluginPath}"
      exec gst-launch-1.0 "$@"
    '';
  };

  gstInspect = pkgs.writeShellApplication {
    name = "rock5c-gst-inspect";
    runtimeInputs = gstPackages;
    text = ''
      export GST_PLUGIN_SYSTEM_PATH_1_0="${gstPluginPath}"
      exec gst-inspect-1.0 "$@"
    '';
  };

  gstH264Test = pkgs.writeShellApplication {
    name = "rock5c-hwdec-h264-test";
    runtimeInputs = gstPackages;
    text = ''
      set -eu

      if [ "$#" -ne 1 ]; then
        echo "usage: rock5c-hwdec-h264-test /path/to/file.mp4" >&2
        exit 2
      fi

      export GST_PLUGIN_SYSTEM_PATH_1_0="${gstPluginPath}"

      exec gst-launch-1.0 -q \
        filesrc location="$1" \
        ! qtdemux \
        ! h264parse \
        ! v4l2slh264dec \
        ! fakesink num-buffers=120 sync=false
    '';
  };

  gstHevcTest = pkgs.writeShellApplication {
    name = "rock5c-hwdec-hevc-test";
    runtimeInputs = gstPackages;
    text = ''
      set -eu

      if [ "$#" -ne 1 ]; then
        echo "usage: rock5c-hwdec-hevc-test /path/to/file.mkv" >&2
        exit 2
      fi

      export GST_PLUGIN_SYSTEM_PATH_1_0="${gstPluginPath}"

      exec gst-launch-1.0 -q \
        filesrc location="$1" \
        ! matroskademux \
        ! h265parse \
        ! v4l2slh265dec \
        ! fakesink num-buffers=120 sync=false
    '';
  };
in
{
  options.dev.johnrinehart.rock5c.gstreamerHwdec.enable =
    lib.mkEnableOption "Rock 5C GStreamer stateless hardware decode tools";

  config = lib.mkIf cfg.enable {
    environment.variables.GST_PLUGIN_SYSTEM_PATH_1_0 = gstPluginPath;

    environment.systemPackages =
      gstPackages
      ++ [
        gstLaunch
        gstInspect
        gstH264Test
        gstHevcTest
      ];

    environment.shellAliases = {
      "gst-launch-1.0-rock5c" = "${gstLaunch}/bin/rock5c-gst-launch";
      "gst-inspect-1.0-rock5c" = "${gstInspect}/bin/rock5c-gst-inspect";
    };
  };
}
