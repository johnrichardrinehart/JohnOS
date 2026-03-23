# Custom packages for JohnOS
{ pkgs }:

let
  rock5cFlashImage = pkgs.callPackage ../nixos-modules/rock5c/flash-image.nix { };
  flashRock5cSd = pkgs.writeShellScriptBin "flash-rock5c-sd" ''
    exec ${rock5cFlashImage}/bin/rock5c-flash-image --target-type sd "$@"
  '';
  flashRock5cEmmc = pkgs.writeShellScriptBin "flash-rock5c-emmc" ''
    exec ${rock5cFlashImage}/bin/rock5c-flash-image --target-type emmc "$@"
  '';
  ffmpegV4l2RequestPatches = [
    ../patches/ffmpeg-v4l2request/0001-h264-slice-bitsize.patch
    ../patches/ffmpeg-v4l2request/0002-hwdevice-v4l2request.patch
    ../patches/ffmpeg-v4l2request/0003-common-v4l2request.patch
    ../patches/ffmpeg-v4l2request/0004-probe-capable-devices.patch
    ../patches/ffmpeg-v4l2request/0005-common-decode-support.patch
    ../patches/ffmpeg-v4l2request/0006-mpeg2-v4l2request.patch
    ../patches/ffmpeg-v4l2request/0007-h264-v4l2request.patch
    ../patches/ffmpeg-v4l2request/0008-hevc-v4l2request.patch
    ../patches/ffmpeg-v4l2request/0009-ffmpeg8-v4l2-request-compat.patch
  ];
  mkV4l2RequestFfmpeg = ffmpegPkg:
    ffmpegPkg.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ ffmpegV4l2RequestPatches;
      configureFlags = (old.configureFlags or [ ]) ++ [ "--enable-v4l2-request" ];
      buildInputs = (old.buildInputs or [ ]) ++ [ pkgs.systemd ];
    });
  ffmpeg8V4l2Request = mkV4l2RequestFfmpeg pkgs.ffmpeg_8;
  ffmpeg8FullV4l2Request = mkV4l2RequestFfmpeg pkgs.ffmpeg_8-full;
  mpvUnwrappedV4l2Request = pkgs."mpv-unwrapped".override {
    ffmpeg = ffmpeg8FullV4l2Request;
  };
  mpvV4l2Request = (mpvUnwrappedV4l2Request.wrapper {
    mpv = mpvUnwrappedV4l2Request;
  }).overrideAttrs
    (old: {
      passthru = (old.passthru or { }) // {
        ffmpeg = ffmpeg8FullV4l2Request;
        unwrapped = mpvUnwrappedV4l2Request;
      };
    });
in
{
  rock5c-flash-image = rock5cFlashImage;
  flash-rock5c-sd = flashRock5cSd;
  flash-rock5c-emmc = flashRock5cEmmc;
  ffmpeg_8-v4l2request = ffmpeg8V4l2Request;
  ffmpeg_8-full-v4l2request = ffmpeg8FullV4l2Request;
  mpv_v4l2request = mpvV4l2Request;
}
