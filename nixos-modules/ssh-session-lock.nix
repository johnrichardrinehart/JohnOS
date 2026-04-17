{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dev.johnrinehart.sshSessionLock;
in
{
  options.dev.johnrinehart.sshSessionLock = {
    enable = lib.mkEnableOption "idle SSH session locking via a terminal multiplexer";

    timeoutSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 60 * 5;
      description = "Maximum SSH TTY idle time before the idle hook locks the matching terminal multiplexer client.";
    };

    suspendPromptTimeoutSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 60 * 15;
      description = "Grace period for SSH sessions to show activity before suspend-then-hibernate proceeds.";
    };

    terminalMultiplexer = lib.mkOption {
      type = lib.types.enum [
        "tmux"
        "none"
      ];
      default = "tmux";
      description = "Terminal multiplexer to lock for idle SSH sessions.";
    };

    forceInteractiveShellsIntoMultiplexer = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Attach interactive SSH shell logins to the configured terminal multiplexer.";
    };

    multiplexerSessionName = lib.mkOption {
      type = lib.types.str;
      default = "main";
      description = "Session name prefix to use when forcing interactive SSH shell logins into the terminal multiplexer.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = lib.optional (cfg.terminalMultiplexer == "tmux") pkgs.tmux;
  };
}
