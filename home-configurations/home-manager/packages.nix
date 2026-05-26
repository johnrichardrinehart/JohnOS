{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dev.johnrinehart.home-manager.packages;
  primaryUser = config.dev.johnrinehart.users.primary;
in
{
  options.dev.johnrinehart.home-manager.packages = {
    shell.enable = lib.mkEnableOption "Shell tools (fzf)";
    games.enable = lib.mkEnableOption "Games (gnuchess, stockfish)";
    messaging.enable = lib.mkEnableOption "Messaging apps (telegram-desktop, signal-desktop)";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.shell.enable {
      home-manager.users.${primaryUser}.home.packages = [
        pkgs.fzf
      ];
    })

    (lib.mkIf cfg.games.enable {
      home-manager.users.${primaryUser}.home.packages = [
        pkgs.gnuchess
        pkgs.stockfish
      ];
    })

    (lib.mkIf cfg.messaging.enable {
      home-manager.users.${primaryUser}.home.packages = [
        pkgs.telegram-desktop
        pkgs.signal-desktop
      ];
    })
  ];
}
