{ config, lib, pkgs, ... }:
let
  cfg = config.dev.johnrinehart.auto-suspend;

  # Script to check battery and suspend if needed
  checkBatteryScript = pkgs.writeShellScript "check-battery" ''
    set -euo pipefail

    # State file to track last action to avoid repeated suspends
    STATE_FILE="/var/lib/auto-suspend/last-action"
    ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$STATE_FILE")"

    # Get battery percentage using upower
    BATTERY_PATH=$(${pkgs.upower}/bin/upower -e | ${pkgs.gnugrep}/bin/grep -i battery | ${pkgs.coreutils}/bin/head -n1)

    if [ -z "$BATTERY_PATH" ]; then
      echo "No battery found, skipping auto-suspend check"
      exit 0
    fi

    # Get battery info
    BATTERY_INFO=$(${pkgs.upower}/bin/upower -i "$BATTERY_PATH")
    PERCENTAGE=$(echo "$BATTERY_INFO" | ${pkgs.gnugrep}/bin/grep -w percentage | ${pkgs.gawk}/bin/awk '{print $2}' | ${pkgs.coreutils}/bin/tr -d '%')
    STATE=$(echo "$BATTERY_INFO" | ${pkgs.gnugrep}/bin/grep -w state | ${pkgs.gawk}/bin/awk '{print $2}')
    CAPACITY_LEVEL=$(echo "$BATTERY_INFO" | ${pkgs.gnugrep}/bin/grep "capacity-level" | ${pkgs.gawk}/bin/awk '{print $2}')
    ENERGY=$(echo "$BATTERY_INFO" | ${pkgs.gnugrep}/bin/grep "^\s*energy:" | ${pkgs.gawk}/bin/awk '{print $2}')
    ENERGY_FULL=$(echo "$BATTERY_INFO" | ${pkgs.gnugrep}/bin/grep "energy-full:" | ${pkgs.gawk}/bin/awk '{print $2}')

    # Calculate energy thresholds from percentages
    LOW_ENERGY_THRESHOLD=$(echo "$ENERGY_FULL * ${toString cfg.lowLevel} / 100" | ${pkgs.bc}/bin/bc -l)
    CRITICAL_ENERGY_THRESHOLD=$(echo "$ENERGY_FULL * ${toString cfg.criticalLevel} / 100" | ${pkgs.bc}/bin/bc -l)

    # Don't suspend if charging or fully charged
    if [ "$STATE" = "charging" ] || [ "$STATE" = "fully-charged" ]; then
      echo "Battery is $STATE ($PERCENTAGE%, $ENERGY Wh), not suspending"
      # Clear state file when charging
      ${pkgs.coreutils}/bin/rm -f "$STATE_FILE"
      exit 0
    fi

    # Read last action from state file
    LAST_ACTION=""
    if [ -f "$STATE_FILE" ]; then
      LAST_ACTION=$(${pkgs.coreutils}/bin/cat "$STATE_FILE")
    fi

    echo "Battery at $PERCENTAGE% ($ENERGY Wh of $ENERGY_FULL Wh), capacity-level: $CAPACITY_LEVEL, state: $STATE, last action: $LAST_ACTION"
    echo "Thresholds: low=${toString cfg.lowLevel}% ($LOW_ENERGY_THRESHOLD Wh), critical=${toString cfg.criticalLevel}% ($CRITICAL_ENERGY_THRESHOLD Wh)"

    # Critical level: UPower says "critical" OR energy below calculated threshold
    if [ "$CAPACITY_LEVEL" = "critical" ] || ([ -n "$ENERGY" ] && [ "$(echo "$ENERGY < $CRITICAL_ENERGY_THRESHOLD" | ${pkgs.bc}/bin/bc)" = "1" ]); then
      if [ "$LAST_ACTION" != "critical" ]; then
        echo "Battery critical (capacity-level=$CAPACITY_LEVEL or $ENERGY Wh < $CRITICAL_ENERGY_THRESHOLD Wh [${toString cfg.criticalLevel}%]), attempting suspend-then-hibernate"
        echo "critical" > "$STATE_FILE"

        # Check if swap is available
        if ${pkgs.util-linux}/bin/swapon --show | ${pkgs.gnugrep}/bin/grep -q .; then
          echo "Swap available, using suspend-then-hibernate"
          ${pkgs.systemd}/bin/systemctl suspend-then-hibernate
        else
          echo "No swap available, falling back to suspend"
          ${pkgs.systemd}/bin/systemctl suspend
        fi
      else
        echo "Already suspended at critical level, skipping"
      fi
      exit 0
    fi

    # Low level: UPower says "low" OR energy below calculated threshold
    if [ "$CAPACITY_LEVEL" = "low" ] || ([ -n "$ENERGY" ] && [ "$(echo "$ENERGY < $LOW_ENERGY_THRESHOLD" | ${pkgs.bc}/bin/bc)" = "1" ]); then
      if [ "$LAST_ACTION" != "low" ] && [ "$LAST_ACTION" != "critical" ]; then
        echo "Battery low (capacity-level=$CAPACITY_LEVEL or $ENERGY Wh < $LOW_ENERGY_THRESHOLD Wh [${toString cfg.lowLevel}%]), suspending"
        echo "low" > "$STATE_FILE"
        ${pkgs.systemd}/bin/systemctl suspend
      else
        echo "Already suspended at low level, skipping"
      fi
      exit 0
    fi

    # Battery is above thresholds, clear state
    if [ "$CAPACITY_LEVEL" != "low" ] && [ "$CAPACITY_LEVEL" != "critical" ] && [ -n "$LAST_ACTION" ]; then
      echo "Battery recovered (capacity-level=$CAPACITY_LEVEL), clearing state"
      ${pkgs.coreutils}/bin/rm -f "$STATE_FILE"
    fi
  '';
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
