{ config, lib, pkgs, ... }:
let
  cfg = config.dev.johnrinehart.auto-suspend;

  # Script to check battery and suspend if needed
  checkBatteryScript = pkgs.writeShellScript "check-battery" ''
    set -euo pipefail

    # State files to track actions and notifications
    STATE_DIR="/var/lib/auto-suspend"
    STATE_FILE="$STATE_DIR/last-action"
    NOTIFIED_FILE="$STATE_DIR/notified-levels"
    ${pkgs.coreutils}/bin/mkdir -p "$STATE_DIR"

    # Function to suspend with fallback
    do_suspend() {
      if ${pkgs.systemd}/bin/systemctl suspend-then-hibernate; then
        echo "Successfully initiated suspend-then-hibernate"
      else
        echo "suspend-then-hibernate failed, falling back to suspend"
        ${pkgs.systemd}/bin/systemctl suspend
      fi
    }

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

    # Function to send notification to user session
    send_notification() {
      local title="$1"
      local message="$2"
      local urgency="$3"

      # Find the user's UID and DBUS session
      for uid in $(${pkgs.coreutils}/bin/ls /run/user/ 2>/dev/null); do
        if [ -S "/run/user/$uid/bus" ]; then
          # Get username from UID
          username=$(${pkgs.coreutils}/bin/id -un "$uid" 2>/dev/null || echo "")
          if [ -n "$username" ]; then
            DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
              ${pkgs.su}/bin/su -s ${pkgs.bash}/bin/sh "$username" -c \
              "${pkgs.libnotify}/bin/notify-send --urgency=$urgency --app-name='Auto-Suspend' '$title' '$message'" 2>/dev/null || true
          fi
        fi
      done
    }

    # Don't suspend if charging or fully charged
    if [ "$STATE" = "charging" ] || [ "$STATE" = "fully-charged" ]; then
      echo "Battery is $STATE ($PERCENTAGE%, $ENERGY Wh), not suspending"
      # Clear state files when charging
      ${pkgs.coreutils}/bin/rm -f "$STATE_FILE" "$NOTIFIED_FILE"
      exit 0
    fi

    # Read last action from state file
    LAST_ACTION=""
    if [ -f "$STATE_FILE" ]; then
      LAST_ACTION=$(${pkgs.coreutils}/bin/cat "$STATE_FILE")
    fi

    echo "Battery at $PERCENTAGE% ($ENERGY Wh of $ENERGY_FULL Wh), capacity-level: $CAPACITY_LEVEL, state: $STATE, last action: $LAST_ACTION"
    echo "Thresholds: low=${toString cfg.lowLevel}% ($LOW_ENERGY_THRESHOLD Wh), critical=${toString cfg.criticalLevel}% ($CRITICAL_ENERGY_THRESHOLD Wh)"

    # Check notification levels and send ONE notification per check
    # Sort levels in ascending order to find the lowest (most urgent) uncrossed threshold
    NOTIFICATION_LEVELS="${pkgs.lib.concatStringsSep " " (map toString (pkgs.lib.sort (a: b: a < b) cfg.notificationLevels))}"
    NOTIFIED_LEVELS=""
    if [ -f "$NOTIFIED_FILE" ]; then
      NOTIFIED_LEVELS=$(${pkgs.coreutils}/bin/cat "$NOTIFIED_FILE")
    fi

    # Find the lowest (most urgent) threshold that was crossed but not yet notified
    NOTIFY_LEVEL=""
    for level in $NOTIFICATION_LEVELS; do
      if [ "$PERCENTAGE" -le "$level" ]; then
        if ! echo "$NOTIFIED_LEVELS" | ${pkgs.gnugrep}/bin/grep -q "\\<$level\\>"; then
          NOTIFY_LEVEL="$level"
          # Keep looking for lower levels (more urgent)
        fi
      fi
    done

    # Send notification for the lowest (most urgent) uncrossed threshold only
    if [ -n "$NOTIFY_LEVEL" ]; then
      echo "Battery crossed $NOTIFY_LEVEL% threshold, sending notification"

      # Determine urgency and message based on current battery percentage and what action will be taken
      # Take into account LAST_ACTION to reflect whether system already suspended
      if [ "$PERCENTAGE" -le ${toString cfg.criticalLevel} ]; then
        urgency="critical"
        if [ "$LAST_ACTION" = "critical" ]; then
          message="Battery critically low at $PERCENTAGE%! System will power off soon."
        else
          message="Battery critically low at $PERCENTAGE%! System will suspend-then-hibernate immediately."
        fi
      elif [ "$PERCENTAGE" -le ${toString cfg.lowLevel} ]; then
        urgency="low"
        if [ "$LAST_ACTION" = "low" ]; then
          message="Battery at $PERCENTAGE%. Critical level will be reached soon."
        else
          message="Battery at $PERCENTAGE%. System will suspend soon."
        fi
      else
        urgency="normal"
        message="Battery at $PERCENTAGE%. Please plug in charger."
      fi

      send_notification "Low Battery" "$message" "$urgency"

      # Mark ALL crossed levels as notified to avoid duplicate notifications
      for level in $NOTIFICATION_LEVELS; do
        if [ "$PERCENTAGE" -le "$level" ]; then
          if ! echo "$NOTIFIED_LEVELS" | ${pkgs.gnugrep}/bin/grep -q "\\<$level\\>"; then
            echo "$level" >> "$NOTIFIED_FILE"
          fi
        fi
      done
    fi

    # Critical level: UPower says "critical" OR energy below calculated threshold
    if [ "$CAPACITY_LEVEL" = "critical" ] || ([ -n "$ENERGY" ] && [ "$(echo "$ENERGY < $CRITICAL_ENERGY_THRESHOLD" | ${pkgs.bc}/bin/bc)" = "1" ]); then
      if [ "$LAST_ACTION" != "critical" ]; then
        echo "Battery critical (capacity-level=$CAPACITY_LEVEL or $ENERGY Wh < $CRITICAL_ENERGY_THRESHOLD Wh [${toString cfg.criticalLevel}%]), attempting suspend-then-hibernate"
        echo "critical" > "$STATE_FILE"
        do_suspend
      else
        echo "Already suspended at critical level, skipping"
      fi
      exit 0
    fi

    # Low level: UPower says "low" OR energy below calculated threshold
    if [ "$CAPACITY_LEVEL" = "low" ] || ([ -n "$ENERGY" ] && [ "$(echo "$ENERGY < $LOW_ENERGY_THRESHOLD" | ${pkgs.bc}/bin/bc)" = "1" ]); then
      if [ "$LAST_ACTION" != "low" ] && [ "$LAST_ACTION" != "critical" ]; then
        echo "Battery low (capacity-level=$CAPACITY_LEVEL or $ENERGY Wh < $LOW_ENERGY_THRESHOLD Wh [${toString cfg.lowLevel}%]), attempting suspend-then-hibernate"
        echo "low" > "$STATE_FILE"
        do_suspend
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

    # Note: Notification state is only cleared when charging (see above)
    # This ensures one notification per level per discharge cycle
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

    notificationLevels = lib.mkOption {
      type = lib.types.listOf lib.types.int;
      default = [ 20 15 10 5 ];
      description = ''
        Battery percentage levels at which to send notifications (default: [20 15 10 5]).
        Notifications are sent once per level each time you discharge from above the highest level.
        Notification state is ONLY cleared when charging, ensuring you get fresh warnings on each discharge cycle.
      '';
      example = [ 30 20 15 10 5 3 1 ];
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
