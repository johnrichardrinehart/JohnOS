## Origin

These patches come from the `v4l2request-2024-v2` branch of Kwiboo's FFmpeg fork:

- Repo: `https://github.com/Kwiboo/FFmpeg`
- Branch: `v4l2request-2024-v2`

This branch carries an out-of-tree V4L2 Request API decode series for stateless
hardware decoders. For Rock 5C / RK3588, this is the relevant FFmpeg-side API
for the `rkvdec` stateless decoder path.

Stock FFmpeg 8.0 does not include:

- `AV_HWDEVICE_TYPE_V4L2REQUEST`
- `--enable-v4l2-request`
- `h264_v4l2request`
- `hevc_v4l2request`

So these patches are carried locally until the required support lands upstream
or a better-maintained FFmpeg 8 request-API branch is available.

## Patch Mapping

The vendored files in this directory correspond to these source commits:

1. `0001-h264-slice-bitsize.patch`
   - Source commit: `f74a24a6c3323a8d03064671565c35109741906a`
   - Subject: `avcodec/h264dec: add ref_pic_marking and pic_order_cnt bit_size to slice context`

2. `0002-hwdevice-v4l2request.patch`
   - Source commit: `11fba12a6a52e87281043d3faa968b97ee666aa2`
   - Subject: `avutil/hwcontext: Add hwdevice type for V4L2 Request API`
   - Note: locally rebased for FFmpeg 8 `libavutil` layout

3. `0003-common-v4l2request.patch`
   - Source commit: `cb1c7806a33d1b87e023646d96c7498833d9ba96`
   - Subject: `avcodec: Add common V4L2 Request API code`

4. `0004-probe-capable-devices.patch`
   - Source commit: `77f9d33cf45d9660643a655bc50f05adc4a240de`
   - Subject: `avcodec/v4l2request: Probe for a capable media and video device`

5. `0005-common-decode-support.patch`
   - Source commit: `d3cb9c6b3bbe0a1211aa6469dfd9f4a55dd5894f`
   - Subject: `avcodec/v4l2request: Add common decode support for hwaccels`

6. `0006-mpeg2-v4l2request.patch`
   - Source commit: `3ba9f35450697d8deeb19e4936baa2b2c04a34a9`
   - Subject: `avcodec: Add V4L2 Request API mpeg2 hwaccel`

7. `0007-h264-v4l2request.patch`
   - Source commit: `cfa8b0f517f332e3093422670fd7ab304144730e`
   - Subject: `avcodec: Add V4L2 Request API h264 hwaccel`

8. `0008-hevc-v4l2request.patch`
   - Source commit: `2af4006b7a3506d439eaf725b3d45579740b1026`
   - Subject: `avcodec: Add V4L2 Request API hevc hwaccel`

9. `0009-ffmpeg8-v4l2-request-compat.patch`
   - Source commit: local patch
   - Subject: `ffmpeg8: relax v4l2-request configure gate for older kernel headers`

10. `0010-hevc-v4l2request-submit-ext-sps-rps.patch`
   - Source commit: local patch
   - Subject: `avcodec/v4l2_request_hevc: submit ext SPS RPS controls`
   - Note: fixes RK3588 10-bit HEVC corruption by queueing the newer
     `V4L2_CID_STATELESS_HEVC_EXT_SPS_ST_RPS` /
     `V4L2_CID_STATELESS_HEVC_EXT_SPS_LT_RPS` controls that the original
     HEVC request-series patch did not submit

## Local Notes

- These patches are vendored instead of fetched dynamically so Nix builds do
  not depend on `fetchpatch2` normalization or network access during iteration.
- The current goal is to get FFmpeg 8-based userspace, including Kodi 22, to
  drive the Rockchip RK3588 stateless decoder path exposed by the patched Rock
  5C kernel.
- `0002-hwdevice-v4l2request.patch` is locally rebased for FFmpeg 8 `libavutil`
  layout changes.
- `0009-ffmpeg8-v4l2-request-compat.patch` is a local compatibility patch for
  older kernel headers in the current nixpkgs branch.
- `0010-hevc-v4l2request-submit-ext-sps-rps.patch` is a local HEVC fix for
  kernels/userspace that expose the ext SPS RPS controls; it was developed
  against Rockchip RK3588 `vdpu381` after kernel tracing showed that FFmpeg
  was not submitting any nonzero short-term RPS payload to the decoder.
