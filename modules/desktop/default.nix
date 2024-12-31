{ inputs, config, pkgs, lib, ... }:
let
  cfg = config.dev.johnrinehart.desktop;
in
{
  options.dev.johnrinehart.desktop = {
    enable = lib.mkEnableOption "reasonable desktop configuration.";
    obsidian = lib.mkEnableOption "packaging Obsidian into the system.";
  };

  imports = [
    inputs.home-manager.nixosModules.default
    ./xorg.nix
  ];

  config = lib.mkIf cfg.enable {
		nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) (lib.optional cfg.obsidian.enable [
			"obsidian"
		]);

    nixpkgs.config.permittedInsecurePackages = lib.mkIf cfg.obsidian [
      "electron-25.9.0"
    ];

    environment.systemPackages = lib.mkIf cfg.obsidian [
      pkgs.obsidian
    ];

    dev.johnrinehart = {
      sound.enable = true;
      systemPackages.enable = true;
      xmonad.enable = true;
      bluetooth.enable = true;
    };
  };
}
