These patches are vendored from Collabora's `rockchip-v6.19` branch:

- Remote: `https://gitlab.collabora.com/hardware-enablement/rockchip-3588/linux.git`
- Branch: `rockchip-v6.19`

Why they are vendored here:
- upstream `v6.19.7` already has the generic `rkvdec` driver, but not the RK3588
  `vdpu381` support needed for Rock 5C H.264 and HEVC decode
- this patch set backports Collabora's RK3588 `rkvdec` work into the local Rock 5C
  kernel packaging

What is intentionally not included:
- Collabora commit `9cab0143c5adaf36b31e757c286c1970185b0f98`
  (`arm64: defconfig: enable Rockchip VDEC`)
  The NixOS module sets `CONFIG_VIDEO_ROCKCHIP_VDEC=m` declaratively instead of
  patching `arch/arm64/configs/defconfig`.

Patch origins:

- `0001-media-v4l2-add-hevc-ext-rps-controls-needed-by-rkvdec.patch`
  Derived from Collabora's `rockchip-v6.19` branch diff against upstream
  `v6.19.7` for:
  `include/uapi/linux/v4l2-controls.h`,
  `drivers/media/v4l2-core/v4l2-ctrls-core.c`, and
  `drivers/media/v4l2-core/v4l2-ctrls-defs.c`.
  This patch adds the HEVC short-term and long-term reference picture set
  controls required by the RK3588 `rkvdec` backport.

- `0002-media-v4l2-add-hevc-ext-rps-control-types.patch`
  Derived from Collabora's `rockchip-v6.19` branch diff against upstream
  `v6.19.7` for `include/uapi/linux/videodev2.h`.
  This patch adds the missing `enum v4l2_ctrl_type` values for the HEVC
  short-term and long-term reference picture set controls added by `0001`.

- `9f8c2200e6297d07fb1e047c2c2d090b01fccff0.patch`
  `media: rkvdec: Switch to using structs instead of writel`
- `cf47a636c7fc530d6907ae7f573ac2544b73e40b.patch`
  `media: rkvdec: Move cabac tables to their own source file`
- `1a0d65a0d565d9be53432e03c7cf9b7b939f7ac4.patch`
  `media: rkvdec: Use structs to represent the HW RPS`
- `f8ce828f2d6dcb61ad011686e520aadc9e06a674.patch`
  `media: rkvdec: Move h264 functions to common file`
- `e741b248274f1c458078c8d8ba3633bd5b3114e6.patch`
  `media: rkvdec: Move hevc functions to common file`
- `c0a3d31c0b1c1f883f4aa1222cdd2cca0133f12e.patch`
  `media: rkvdec: Add variant specific coded formats list`
- `0eb2e81f78630ed09a35b45661d09316fdb58d5e.patch`
  `media: rkvdec: Add RCB and SRAM support`
- `2dc54c81347f96b3560a63e4b1256d77e1db5081.patch`
  `media: rkvdec: Support per-variant interrupt handler`
- `9f3ee0cab02e5016bff48f37ab07a453e53a8a21.patch`
  `media: rkvdec: Enable all clocks without naming them`
- `8f6ded94e3ad82791d07059df9283052bc1467e9.patch`
  `media: rkvdec: Disable multicore support`
- `bd3696a4216406f992cfaacce40a6c9a3e3ab2ce.patch`
  `media: rkvdec: Add H264 support for the VDPU381 variant`
- `360cc01f6be136bcc3f03b9bd63f2eeb758bb7d4.patch`
  `media: rkvdec: Add H264 support for the VDPU383 variant`
- `a2be7ad764ecfd1175945ee7bbfbea21b7a9dfd1.patch`
  `media: rkvdec: Add HEVC support for the VDPU381 variant`
- `0effad757855291d40d774c37dae037822c6e7e1.patch`
  `media: rkvdec: Add HEVC support for the VDPU383 variant`
- `2b877e1f44cb825ebe8ebf0ff17e86e0f41565b8.patch`
  `arm64: dts: rockchip: Add the vdpu381 Video Decoders on RK3588`
