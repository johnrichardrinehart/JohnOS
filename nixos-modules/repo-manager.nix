{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dev.johnrinehart.repo-manager;
  primaryUser = config.dev.johnrinehart.users.primary;
  format = pkgs.formats.json { };
  configFile = format.generate "repo-manager-config.json" cfg.settings;
in
{
  options.dev.johnrinehart.repo-manager = {
    enable = lib.mkEnableOption "repo-manager configuration";

    package = lib.mkPackageOption pkgs.dev.johnrinehart "repo-manager" { };

    settings = lib.mkOption {
      inherit (format) type;
      default = {
        cache_root = "/home/${primaryUser}/.cache/repo-manager";
        auto_create_remote = false;
        clone_as_bare = true;
        config_version = 1;
        clone_start_ttl_minutes = 60;
        detect_related = true;
        root = "/home/${primaryUser}/code";
        rpc_rate_limit_per_second = 1;
        state = "/home/${primaryUser}/.local/state/repo-manager/repos.sqlite";
      };
      description = ''
        repo-manager JSON configuration written to
        ~/.config/repo-manager/config.json for the primary user.
      '';
    };

    daemon = {
      enable = lib.mkEnableOption "the repo-manager user daemon";
      package = lib.mkPackageOption pkgs.dev.johnrinehart "repod" { };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      cfg.package
    ]
    ++ lib.optional cfg.daemon.enable cfg.daemon.package;

    home-manager.users.${primaryUser} = {
      xdg.configFile."repo-manager/config.json".source = configFile;

      systemd.user.services.repod = lib.mkIf cfg.daemon.enable {
        Unit = {
          Description = "repo-manager RPC daemon";
        };

        Service = {
          ExecStart = lib.getExe cfg.daemon.package;
          Restart = "on-failure";
        };

        Install.WantedBy = [ "default.target" ];
      };
    };
  };
}
