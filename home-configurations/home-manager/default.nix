{ config, lib, ... }:
{
  options.dev.johnrinehart.home-manager = {
    enable = lib.mkEnableOption "John's Home Manager settings.";
  };

  imports = [
    ./dwm
    ./i3
    ./xmonad
    #   ({
    #     home-manager = {
    #       useGlobalPkgs = true;
    #       useUserPackages = true;
    #       users = {
    #         john = ./common.nix;
    #       };
    #     };
    #   })
  ];
}
