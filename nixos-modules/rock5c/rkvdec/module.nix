{
  config,
  lib,
  ...
}:
let
  cfg = config.dev.johnrinehart.rock5c.rkvdec;

  patchFiles = [
    "9f8c2200e6297d07fb1e047c2c2d090b01fccff0.patch"
    "cf47a636c7fc530d6907ae7f573ac2544b73e40b.patch"
    "1a0d65a0d565d9be53432e03c7cf9b7b939f7ac4.patch"
    "f8ce828f2d6dcb61ad011686e520aadc9e06a674.patch"
    "e741b248274f1c458078c8d8ba3633bd5b3114e6.patch"
    "c0a3d31c0b1c1f883f4aa1222cdd2cca0133f12e.patch"
    "0eb2e81f78630ed09a35b45661d09316fdb58d5e.patch"
    "2dc54c81347f96b3560a63e4b1256d77e1db5081.patch"
    "9f3ee0cab02e5016bff48f37ab07a453e53a8a21.patch"
    "8f6ded94e3ad82791d07059df9283052bc1467e9.patch"
    "bd3696a4216406f992cfaacce40a6c9a3e3ab2ce.patch"
    "360cc01f6be136bcc3f03b9bd63f2eeb758bb7d4.patch"
    "a2be7ad764ecfd1175945ee7bbfbea21b7a9dfd1.patch"
    "0effad757855291d40d774c37dae037822c6e7e1.patch"
    "2b877e1f44cb825ebe8ebf0ff17e86e0f41565b8.patch"
  ];
in
{
  options.dev.johnrinehart.rock5c.rkvdec = {
    enable = lib.mkEnableOption "Collabora RK3588 rkvdec backport for Rock 5C";
  };

  config = lib.mkIf cfg.enable {
    boot.kernelModules = [ "rockchip_vdec" ];

    boot.kernelPatches =
      (map (file: {
        name = "rock5c-rkvdec-${lib.removeSuffix ".patch" file}";
        patch = ./patches/${file};
      }) patchFiles)
      ++ [
        {
          name = "rock5c-rkvdec-kconfig";
          patch = null;
          structuredExtraConfig = with lib.kernel; {
            VIDEO_ROCKCHIP_VDEC = module;
          };
        }
      ];
  };
}
