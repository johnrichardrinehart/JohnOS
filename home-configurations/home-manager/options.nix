{
  pkgs,
  lib,
  osConfig,
  ...
}:
{
  options.idle = {
    short_timeout_duration = lib.mkOption {
      description = "Duration (in seconds) to consider a \"short\" idle duration";
      default = 60;
    };
    medium_timeout_duration = lib.mkOption {
      description = "Duration (in seconds) to consider a \"short\" idle duration";
      default = 120;
    };
    long_timeout_duration = lib.mkOption {
      description = "Duration (in seconds) to consider a \"short\" idle duration";
      default = 180;
    };
  };
}
