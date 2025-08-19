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

      alsa.enable = false; # https://github.com/NixOS/nixpkgs/issues/157442
      alsa.support32Bit = false; # https://github.com/NixOS/nixpkgs/issues/157442

      pulse.enable = true;

      # If you want to use JACK applications, uncomment this
      jack.enable = true;

      wireplumber.enable = true;
    };
  };
}
