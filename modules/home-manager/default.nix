{ config, lib, ... }:
{
  options.dev.johnrinehart.desktop = {
    enable = lib.mkEnableOption "John's Desktop settings.";
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
