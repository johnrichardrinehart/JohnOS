{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dev.johnrinehart.desktop.xorg-xmonad;
in
{
  options.dev.johnrinehart.desktop.xorg-xmonad = {
    enable = lib.mkEnableOption "the Xorg with Xmonad configuration.";
  }
  // {
    default = false;
  };

  imports = [
    ./xorg.nix
  ];

  config = lib.mkIf cfg.enable {
    nixpkgs.config.allowUnfreePredicate =
      pkg:
      builtins.elem (lib.getName pkg) (
        lib.optional config.dev.johnrinehart.desktop.obsidian [ "obsidian" ]
      );

    nixpkgs.config.permittedInsecurePackages = lib.optional config.dev.johnrinehart.desktop.obsidian [
      "electron-25.9.0"
    ];

    environment.systemPackages = [
      pkgs.kitty
    ]
    ++ lib.optional config.dev.johnrinehart.desktop.obsidian [
      pkgs.obsidian
    ];

    dev.johnrinehart = {
      xorg.enable = true;
      sound.enable = true;
      packages.shell.enable = true;
      packages.editors.enable = true;
      packages.gui.enable = true;
      packages.devops.enable = true;
      packages.media.enable = true;
      packages.system.enable = true;
      packages.archive.enable = true;
      xmonad.enable = true;
      bluetooth.enable = true;
    };
  };
}
