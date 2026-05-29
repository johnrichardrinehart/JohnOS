{ config, lib, ... }:
let
  cfg = config.dev.johnrinehart.virtualisation;
in
{
  options.dev.johnrinehart.virtualisation = {
    enable = lib.mkEnableOption "enable typical virtualisation stuff";

    binfmtEmulatedSystems = lib.mkOption {
      description = "Systems to emulate with binfmt and userspace qemu.";
      default = [ ];
      type = lib.types.listOf lib.types.str;
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.docker = {
      enable = true;
      storageDriver = "overlay2";
    };

    boot.binfmt.emulatedSystems = cfg.binfmtEmulatedSystems;
  };
}
