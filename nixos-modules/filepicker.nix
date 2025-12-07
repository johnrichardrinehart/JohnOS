{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.dev.johnrinehart.terminal.filepicker;

  # NOTE: I tried for about an hour to get ueberzugpp tweaked to specify kitty
  # output format by command-line, instead of config, since this tool doesn't
  # support /etc/ueberzugpp/config.json config locations, only
  # ~/.config/ueberzugpp. I really don't want ueberguzpp on $PATH. But, I
  # couldn't find a way around it. Maybe a future me can do this.

  #  ueberzugppKitty = pkgs.stdenv.mkDerivation {
  #    name = pkgs.ueberzugpp.name;
  #    version = pkgs.ueberzugpp.version;
  #    dontUnpack = true;
  #    dontBuild = true;
  #    nativeBuildInputs = [ pkgs.makeBinaryWrapper ];
  #    # TOOD: patch ueberzugpp upstream to avoid getExe'
  #    installPhase = ''
  #      makeBinaryWrapper \
  #        "${pkgs.lib.getExe' pkgs.ueberzugpp "ueberzugpp"}" \
  #        $out/bin/ueberzugpp
  #    '';
  #
  #    meta = pkgs.ueberzugpp.meta;
  #  };
  #
  #  ranger = pkgs.stdenv.mkDerivation {
  #    name = pkgs.ranger.name;
  #    version = pkgs.ranger.version;
  #
  #    dontUnpack = true;
  #    dontBuild = true;
  #
  #    nativeBuildInputs = [ pkgs.makeBinaryWrapper ];
  #    installPhase = ''
  #      makeBinaryWrapper \
  #        "${pkgs.lib.getExe pkgs.ranger}" \
  #        $out/bin/ranger \
  #        --set PATH "${pkgs.ueberzugpp}/bin"
  #    '';
  #
  #    meta = pkgs.ranger.meta;
  #  };
in
{
  options.dev.johnrinehart.terminal.filepicker = {
    enable = lib.mkEnableOption "Enable ranger for use as a file picker";

    variant = lib.mkOption {
      description = "choose between a few configured filepickers";
      default = "yazi";
      type = lib.types.enum [
        "yazi"
        "ranger"
      ];
    };
  };

  config =
    let
      rangerConfig = {
        environment.systemPackages = [
          pkgs.ranger
          pkgs.ueberzugpp
        ];

        environment.etc."ranger/rc.conf".source = ./ranger.conf;
      };

      yaziConfig = {
        environment.systemPackages = [
          pkgs.yazi
        ];
      };
    in
    lib.mkIf cfg.enable (
      (lib.mkIf (cfg.variant == "ranger") rangerConfig) // (lib.mkIf (cfg.variant == "yazi") yaziConfig)
    );
}
