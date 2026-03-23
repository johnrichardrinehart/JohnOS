{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dev.johnrinehart.rock5c.ffmpegV4l2Request;

  ffmpegV4l2RequestPatches = with pkgs; [
    (fetchpatch2 {
      name = "ffmpeg-v4l2request-h264-slice-bitsize.patch";
      url = "https://github.com/Kwiboo/FFmpeg/commit/f74a24a6c3323a8d03064671565c35109741906a.patch";
      hash = "sha256-V4F5uUQQ3wGDrg1uRtUxOoCrCfxwqNrYbMVOLC3RhQA=";
    })
    (fetchpatch2 {
      name = "ffmpeg-v4l2request-hwdevice.patch";
      url = "https://github.com/Kwiboo/FFmpeg/commit/11fba12a6a52e87281043d3faa968b97ee666aa2.patch";
      hash = "sha256-qRyb1GHEVqPjdTCSd2zdkFJVey4gFTinPIQRieGvDso=";
    })
    (fetchpatch2 {
      name = "ffmpeg-v4l2request-common.patch";
      url = "https://github.com/Kwiboo/FFmpeg/commit/cb1c7806a33d1b87e023646d96c7498833d9ba96.patch";
      hash = "sha256-oVb8X+tGLgB0nVj7xpMKgQxPHyFs67ygP+c1PUTx3dE=";
    })
    (fetchpatch2 {
      name = "ffmpeg-v4l2request-probe.patch";
      url = "https://github.com/Kwiboo/FFmpeg/commit/77f9d33cf45d9660643a655bc50f05adc4a240de.patch";
      hash = "sha256-DeAbTrqv7AldHgDx7jObK8W0TSAYzz/X97LPBWJ0Emo=";
    })
    (fetchpatch2 {
      name = "ffmpeg-v4l2request-decode-common.patch";
      url = "https://github.com/Kwiboo/FFmpeg/commit/d3cb9c6b3bbe0a1211aa6469dfd9f4a55dd5894f.patch";
      hash = "sha256-IzalkCA27ybl7HzRsVyylaakJVkKjDG84BJDqsm/xmA=";
    })
    (fetchpatch2 {
      name = "ffmpeg-v4l2request-mpeg2.patch";
      url = "https://github.com/Kwiboo/FFmpeg/commit/3ba9f35450697d8deeb19e4936baa2b2c04a34a9.patch";
      hash = "sha256-tj02XNcTBy7CZXeQreJ/uFJ3XSKMIB8FSgrurqItvdQ=";
    })
    (fetchpatch2 {
      name = "ffmpeg-v4l2request-h264.patch";
      url = "https://github.com/Kwiboo/FFmpeg/commit/cfa8b0f517f332e3093422670fd7ab304144730e.patch";
      hash = "sha256-aWu7y0zSkTwPC79KXghAMrrugwsKQpnkA3cWUny1fNg=";
    })
    (fetchpatch2 {
      name = "ffmpeg-v4l2request-hevc.patch";
      url = "https://github.com/Kwiboo/FFmpeg/commit/2af4006b7a3506d439eaf725b3d45579740b1026.patch";
      hash = "sha256-2jthEw3aoUR88jNAYOa1eLkp68lNRe1jAgCeISDRrGE=";
    })
  ];

  overlay = final: prev:
    let
      mkV4l2RequestFfmpeg = ffmpegPkg:
        ffmpegPkg.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ ffmpegV4l2RequestPatches;
          configureFlags = (old.configureFlags or [ ]) ++ [ "--enable-v4l2-request" ];
        });
    in
    {
      ffmpeg_8-v4l2request = mkV4l2RequestFfmpeg prev.ffmpeg_8;
      ffmpeg_8-full-v4l2request = mkV4l2RequestFfmpeg prev.ffmpeg_8-full;
      rock5c-ffmpeg-v4l2request = final.writeShellApplication {
        name = "rock5c-ffmpeg-v4l2request";
        runtimeInputs = [ final.ffmpeg_8-full-v4l2request ];
        text = ''
          exec ffmpeg "$@"
        '';
      };
      rock5c-ffprobe-v4l2request = final.writeShellApplication {
        name = "rock5c-ffprobe-v4l2request";
        runtimeInputs = [ final.ffmpeg_8-full-v4l2request ];
        text = ''
          exec ffprobe "$@"
        '';
      };
      rock5c-ffplay-v4l2request = final.writeShellApplication {
        name = "rock5c-ffplay-v4l2request";
        runtimeInputs = [ final.ffmpeg_8-full-v4l2request ];
        text = ''
          exec ffplay "$@"
        '';
      };
      rock5c-ffmpeg-h264-v4l2request-test = final.writeShellApplication {
        name = "rock5c-ffmpeg-h264-v4l2request-test";
        runtimeInputs = [ final.ffmpeg_8-full-v4l2request ];
        text = ''
          set -eu

          if [ "$#" -ne 1 ]; then
            echo "usage: rock5c-ffmpeg-h264-v4l2request-test /path/to/h264-file" >&2
            exit 2
          fi

          exec ffmpeg \
            -hide_banner \
            -loglevel verbose \
            -init_hw_device v4l2request=rock5c:/dev/media1 \
            -hwaccel v4l2request \
            -hwaccel_device rock5c \
            -hwaccel_output_format drm_prime \
            -c:v h264_v4l2request \
            -i "$1" \
            -an \
            -frames:v 300 \
            -f null -
        '';
      };
      rock5c-ffmpeg-hevc-v4l2request-test = final.writeShellApplication {
        name = "rock5c-ffmpeg-hevc-v4l2request-test";
        runtimeInputs = [ final.ffmpeg_8-full-v4l2request ];
        text = ''
          set -eu

          if [ "$#" -ne 1 ]; then
            echo "usage: rock5c-ffmpeg-hevc-v4l2request-test /path/to/hevc-file" >&2
            exit 2
          fi

          exec ffmpeg \
            -hide_banner \
            -loglevel verbose \
            -init_hw_device v4l2request=rock5c:/dev/media0 \
            -hwaccel v4l2request \
            -hwaccel_device rock5c \
            -hwaccel_output_format drm_prime \
            -c:v hevc_v4l2request \
            -i "$1" \
            -an \
            -frames:v 300 \
            -f null -
        '';
      };
    };
in
{
  options.dev.johnrinehart.rock5c.ffmpegV4l2Request.enable =
    lib.mkEnableOption "Rock 5C FFmpeg/mpv V4L2 request API decode packages";

  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = [ overlay ];

    environment.systemPackages = [
      pkgs.ffmpeg_8-full-v4l2request
      pkgs.rock5c-ffmpeg-v4l2request
      pkgs.rock5c-ffprobe-v4l2request
      pkgs.rock5c-ffplay-v4l2request
      pkgs.rock5c-ffmpeg-h264-v4l2request-test
      pkgs.rock5c-ffmpeg-hevc-v4l2request-test
    ];

    environment.shellAliases = {
      "ffmpeg-v4l2request" = "${pkgs.rock5c-ffmpeg-v4l2request}/bin/rock5c-ffmpeg-v4l2request";
      "ffprobe-v4l2request" = "${pkgs.rock5c-ffprobe-v4l2request}/bin/rock5c-ffprobe-v4l2request";
      "ffplay-v4l2request" = "${pkgs.rock5c-ffplay-v4l2request}/bin/rock5c-ffplay-v4l2request";
    };
  };
}
