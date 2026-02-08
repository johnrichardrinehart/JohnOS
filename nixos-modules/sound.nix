{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.dev.johnrinehart.sound;
in
{
  options.dev.johnrinehart.sound = {
    enable = lib.mkEnableOption "John's sound config";

    debug = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable PipeWire debug logging via PIPEWIRE_DEBUG environment variable.";
      };
      level = lib.mkOption {
        type = lib.types.ints.between 0 5;
        default = 4;
        description = ''
          PipeWire log level: 0=none, 1=errors, 2=warnings, 3=info, 4=debug, 5=trace.
          Level 5 (trace) logs from realtime threads and will impact audio performance.
          Level 4 (debug) is the recommended maximum for ongoing use.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # PAM limits for the @audio group — foundation for realtime audio
    security.pam.loginLimits = [
      { domain = "@audio"; type = "-"; item = "memlock"; value = "unlimited"; }
      { domain = "@audio"; type = "-"; item = "rtprio";  value = "95"; }
      { domain = "@audio"; type = "-"; item = "nice";    value = "-15"; }
    ];

    services.pipewire = {
      enable = true;

      alsa.enable = true;
      alsa.support32Bit = false;
      pulse.enable = true;
      wireplumber.enable = true;

      jack.enable = false;

      extraConfig.pipewire = {
        "10-low-latency" = {
          "context.properties" = {
            "default.clock.quantum" = 512;
            "default.clock.min-quantum" = 256;
            "default.clock.max-quantum" = 1024;
          };
        };
      };
    };

    # Harden PipeWire against swap and resource starvation
    systemd.user.services.pipewire.serviceConfig = lib.mkMerge [
      {
        LimitMEMLOCK = "infinity";
        LimitRTPRIO = 95;
        OOMScoreAdjust = -500;
        IOSchedulingClass = "realtime";
        IOSchedulingPriority = 0;
        Nice = -11;
        MemorySwapMax = "0";
        LockPersonality = true;
      }
      (lib.mkIf cfg.debug.enable {
        Environment = [ "PIPEWIRE_DEBUG=${toString cfg.debug.level}" ];
      })
    ];

    systemd.user.services.wireplumber.serviceConfig = {
      LimitMEMLOCK = "infinity";
      LimitRTPRIO = 95;
      OOMScoreAdjust = -500;
      IOSchedulingClass = "realtime";
      IOSchedulingPriority = 0;
      Nice = -11;
      MemorySwapMax = "0";
    };

  };
}
