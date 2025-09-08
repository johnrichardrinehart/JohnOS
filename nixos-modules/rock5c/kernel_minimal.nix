{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dev.johnrinehart.rock5c;
  readConfig =
    configfile:
    lib.listToAttrs (
      map
        (
          line:
          let
            match = lib.match "(.*)=\"?(.*)\"?" line;
          in
          {
            name = lib.elemAt match 0;
            value = lib.elemAt match 1;
          }
        )
        (
          lib.filter (line: !(lib.hasPrefix "#" line || line == "")) (
            lib.splitString "\n" (builtins.readFile configfile)
          )
        )
    );
in
{
  config = lib.mkIf cfg.useMinimalKernel {
    nixpkgs.overlays = [
      (final: prev: {
        linux_rock5c_minimal = pkgs.linuxManualConfig {
          src = builtins.fetchGit {
            url = "git@github.com:johnrichardrinehart/linux";
            rev = "39162db30263f4931671c06a9aeb6f5a20026d43";
            ref = "jrinehart/v6.16.1/rockchip-video";
            shallow = true;
          };
          version = "6.16.1";
          modDirVersion = "6.16.1";
#          modDirVersion = "6.16.1-00021-g39162db30263";
          configfile = ./rock5c_minimal.config;
          config = readConfig ./rock5c_minimal.config;
        };
      })
    ];

    boot.kernelPackages = pkgs.linuxPackagesFor pkgs.linux_rock5c_minimal;

  };
}
