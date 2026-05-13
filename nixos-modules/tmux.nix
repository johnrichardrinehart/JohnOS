{ config, lib, ... }:
let
  cfg = config.dev.johnrinehart.tmux.clipboard;

  terminalFeaturePatterns = if cfg.assumeAllTerminals then [ "*" ] else cfg.terminalPatterns;

  terminalFeatures = lib.concatMapStringsSep "," (
    pattern: "${pattern}:clipboard"
  ) terminalFeaturePatterns;
in
{
  options.dev.johnrinehart.tmux.clipboard = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Enable system-wide tmux OSC 52 clipboard integration by default.

        When enabled, tmux advertises clipboard support to common local
        terminals and nested tmux/screen clients, and permits tmux copy
        operations to write the terminal clipboard. This lets shells and tmux
        sessions reached over SSH copy back to the local machine's clipboard,
        provided the local terminal emulator allows OSC 52 clipboard writes.

        This is terminal-protocol clipboard integration, not Wayland compositor
        clipboard synchronization. Pasting from the local clipboard into a
        remote tmux pane still uses the local terminal's normal paste path.
      '';
    };

    terminalPatterns = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "xterm*"
        "tmux*"
        "screen*"
        "foot*"
        "kitty*"
        "wezterm*"
        "alacritty*"
      ];
      description = ''
        tmux terminal name patterns that should be marked as supporting the
        clipboard terminal feature.

        These patterns match the tmux client terminal name, usually from
        $TERM, not the user's shell. Include outer multiplexers such as tmux*
        and screen* so OSC 52 clipboard writes can pass through nested tmux
        sessions.

        Set this to an empty list when using assumeAllTerminals.
      '';
    };

    assumeAllTerminals = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Assume every tmux client terminal supports OSC 52 clipboard writes.

        When enabled, the generated tmux configuration uses *:clipboard instead
        of the explicit terminalPatterns list. This is useful when all expected
        clients should receive OSC 52 clipboard attempts, including terminal
        emulators not listed in terminalPatterns.

        This option is mutually exclusive with terminalPatterns; set
        terminalPatterns to an empty list before enabling it.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !cfg.assumeAllTerminals || cfg.terminalPatterns == [ ];
        message = ''
          dev.johnrinehart.tmux.clipboard.assumeAllTerminals is mutually
          exclusive with dev.johnrinehart.tmux.clipboard.terminalPatterns.
          Set terminalPatterns = [] when assumeAllTerminals = true.
        '';
      }
    ];

    programs.tmux = {
      enable = lib.mkDefault true;
      secureSocket = lib.mkDefault false;
      extraConfig = lib.mkAfter ''
        # Enable OSC 52 clipboard writes through tmux, including nested tmux.
        # The local terminal emulator must support and allow OSC 52.
        set -s set-clipboard on
        ${lib.optionalString (
          terminalFeaturePatterns != [ ]
        ) "set -as terminal-features ',${terminalFeatures}'"}
      '';
    };
  };
}
