{
  lib,
  ...
}:
{
  options.dev.johnrinehart.tmux = {
    socketDir = lib.mkOption {
      type = lib.types.str;
      default = "/tmp";
      description = "Base directory used for the canonical tmux server socket.";
    };

    socketName = lib.mkOption {
      type = lib.types.str;
      default = "default";
      description = "Socket filename used for the canonical tmux server.";
    };
  };
}
