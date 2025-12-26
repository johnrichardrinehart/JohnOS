{ config, lib, ... }:
{
  options.dev.johnrinehart.home-manager = {
    enable = lib.mkEnableOption "John's Home Manager settings.";
  };

  imports = [
    ./options.nix
    ({
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        users = {
          john = ./common.nix;
        };
      };
    })
  ];
}
