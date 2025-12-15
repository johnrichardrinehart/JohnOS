{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.dev.johnrinehart.sound;
in
{
  options.dev.johnrinehart.sound = {
    enable = lib.mkEnableOption "John's sound config";
  };

  config = lib.mkIf cfg.enable {
    services.pipewire = {
      enable = true;

      alsa.enable = true;
      alsa.support32Bit = false;
      pulse.enable = true;
      wireplumber.enable = true;

      jack.enable = false;
    };
  };
}
