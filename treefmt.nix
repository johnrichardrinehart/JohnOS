{ pkgs, ... }:
{
  projectRootFile = "flake.nix";

  settings.formatter = {
    markdownlint = {
      command = "${pkgs.markdownlint-cli}/bin/markdownlint";
      includes = [ "*.md" ];
      options = [
        "--disable"
        "MD013"
        "MD040"
        "MD060"
      ];
    };
  };

  programs = {
    actionlint.enable = true;
    deadnix.enable = true;
    nixfmt.enable = true;
    prettier = {
      enable = true;
      includes = [
        "*.css"
        "*.json"
        "*.jsonc"
      ];
    };
    kdlfmt = {
      enable = true;
      package = pkgs.dev.johnrinehart.kdlfmt;
    };
    ruff-check.enable = true;
    ruff-format.enable = true;
    shellcheck.enable = true;
    shfmt.enable = true;
    statix = {
      enable = true;
      disabled-lints = [ "W20" ];
    };
    taplo.enable = true;
    yamllint = {
      enable = true;
      settings = {
        extends = "default";
        ignore = "secrets/sops.yaml";
        rules.truthy.allowed-values = [
          "true"
          "false"
          "on"
          "off"
        ];
      };
    };
  };
}
