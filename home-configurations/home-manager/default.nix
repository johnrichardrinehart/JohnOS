{ config, lib, ... }:
let
  primaryUser = config.dev.johnrinehart.users.primary;
in
{
  options.dev.johnrinehart.home-manager = {
    enable = lib.mkEnableOption "John's Home Manager settings.";
  };

  imports = [
    ./options.nix
    ./packages.nix
    ({
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        users = {
          ${primaryUser} = ./common.nix;
        };
      };
    })
  ];
}
