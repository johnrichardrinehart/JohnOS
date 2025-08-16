{ config, lib, ... }:
let
  cfg = config.dev.johnrinehart.laptop;
in
{
  options.dev.johnrinehart.laptop = {
    enable = lib.mkEnableOption "reasonable laptop settings";
  };

  config = lib.mkIf cfg.enable { services.libinput.enable = true; };
}
