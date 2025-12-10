{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dev.johnrinehart.auto-suspend;

  # Script to check battery and suspend if needed
  checkBatteryScript = import ./auto-suspend-check-battery.nix {
    inherit pkgs;
    lowLevel = cfg.lowLevel;
    criticalLevel = cfg.criticalLevel;
    notificationLevels = cfg.notificationLevels;
  };
in
{
  options.dev.johnrinehart.auto-suspend = {
    enable = lib.mkEnableOption "automatic battery-based suspend";

    lowLevel = lib.mkOption {
      type = lib.types.int;
      default = 15;
      description = ''
        Battery percentage at which to suspend (default: 15%).
        Internally converted to energy (Wh) based on battery capacity for more reliable detection.
        Also triggers when UPower reports 'low' capacity-level.
      '';
    };

    criticalLevel = lib.mkOption {
      type = lib.types.int;
      default = 10;
      description = ''
        Battery percentage at which to suspend-then-hibernate (default: 10%).
        Internally converted to energy (Wh) based on battery capacity for more reliable detection.
        Also triggers when UPower reports 'critical' capacity-level.
      '';
    };

    checkInterval = lib.mkOption {
      type = lib.types.str;
      default = "90s";
      description = "How often to check battery level (systemd timer format, default: 90s)";
    };

    notificationLevels = lib.mkOption {
      type = lib.types.listOf lib.types.int;
      default = [
        20
        15
        10
        5
      ];
      description = ''
        Battery percentage levels at which to send notifications (default: [20 15 10 5]).
        Notifications are sent once per level each time you discharge from above the highest level.
        Notification state is ONLY cleared when charging, ensuring you get fresh warnings on each discharge cycle.
      '';
      example = [
        30
        20
        15
        10
        5
        3
        1
      ];
    };
  };

  config = lib.mkIf cfg.enable {
    # Ensure upower is available
    services.upower.enable = true;

    # Create state directory
    systemd.tmpfiles.rules = [
      "d /var/lib/auto-suspend 0755 root root -"
    ];

    # Systemd service to check battery
    systemd.services.auto-suspend-check = {
      description = "Check battery level and auto-suspend if needed";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${checkBatteryScript}";
        # Run as root to access systemctl suspend
        User = "root";
      };
    };

    # Timer to run the check periodically
    systemd.timers.auto-suspend-check = {
      description = "Timer for battery auto-suspend check";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "1min";
        OnUnitActiveSec = cfg.checkInterval;
        Unit = "auto-suspend-check.service";
      };
    };
  };
}
