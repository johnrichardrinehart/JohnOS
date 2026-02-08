{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.dev.johnrinehart.bluetooth;

  btIdleScript = pkgs.writeShellScript "bt-auto-suspend" ''
    count_file="/run/bt-idle-count"

    # Check for connected devices
    connected=$(${pkgs.bluez}/bin/bluetoothctl devices Connected 2>/dev/null)

    if [ -n "$connected" ]; then
      # Devices connected — reset counter
      echo 0 > "$count_file"
      exit 0
    fi

    # Check if adapter is already powered off
    powered=$(${pkgs.bluez}/bin/bluetoothctl show 2>/dev/null | grep "Powered: yes")
    if [ -z "$powered" ]; then
      # Already off, nothing to do
      echo 0 > "$count_file"
      exit 0
    fi

    # No devices connected — increment counter
    current=$(cat "$count_file" 2>/dev/null || echo 0)
    current=$((current + 1))
    echo "$current" > "$count_file"

    # If idle long enough, power off
    if [ "$current" -ge "${toString cfg.autoSuspend.idleMinutes}" ]; then
      ${pkgs.bluez}/bin/bluetoothctl power off
      echo 0 > "$count_file"
    fi
  '';
in
{
  options.dev.johnrinehart.bluetooth = {
    enable = lib.mkEnableOption "John's Bluetooth settings.";

    autoSuspend = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Automatically power off the Bluetooth adapter after a period of inactivity
          (no connected devices). To wake Bluetooth back up, run `bluetoothctl power on`.
        '';
      };
      idleMinutes = lib.mkOption {
        type = lib.types.ints.positive;
        default = 3;
        description = ''
          Number of minutes with no connected Bluetooth devices before powering off
          the adapter. The check runs every 60 seconds.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    hardware.bluetooth = {
      enable = true;
      settings = {
        General = {
          Enable = "Source,Sink,Media,Socket";
          AutoEnable = false;
        };
      };
    };

    services.blueman.enable = true;

    # System-level timer to auto-suspend bluetooth when idle
    systemd.services.bt-auto-suspend = lib.mkIf cfg.autoSuspend.enable {
      description = "Check for connected Bluetooth devices and power off adapter if idle";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = btIdleScript;
      };
    };

    systemd.timers.bt-auto-suspend = lib.mkIf cfg.autoSuspend.enable {
      description = "Periodically check Bluetooth idle status";
      wantedBy = [ "multi-user.target" ];
      timerConfig = {
        OnBootSec = "2min";
        OnUnitActiveSec = "1min";
        Unit = "bt-auto-suspend.service";
      };
    };
  };
}
