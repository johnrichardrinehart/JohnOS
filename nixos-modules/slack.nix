{ pkgs, ... }:
let
  cfg = config.dev.johnrinehart.slack;
in
{
  options.dev.johnrinehart.slack = {
    enable = lib.mkEnableOption "slack desktop application";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.slack ];

    nixpkgs.config.allowUnfreePredicate =
      pkg:
      builtins.elem (lib.getName pkg) [
        "slack"
      ];
  };
}
