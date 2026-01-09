# Thunderbolt and PCI power management debugging module
#
# Enables verbose logging for diagnosing Thunderbolt/USB4 DisplayPort tunnel
# failures during suspend/hibernate. Useful for capturing diagnostic data
# to share with kernel developers.
#
# Usage:
#   dev.johnrinehart.thunderbolt-debug.enable = true;
#
# When enabled:
#   - CONFIG_PCI_DEBUG is set in the kernel
#   - Dynamic debug (dyndbg) params for PCI/TB are available (commented by default)
#   - Runtime debug can be enabled via /proc/dynamic_debug/control
#
# To enable verbose logging at runtime:
#   echo "file drivers/pci/pci.c +p" | sudo tee /proc/dynamic_debug/control
#   echo "module thunderbolt +p" | sudo tee /proc/dynamic_debug/control
#
# To enable at boot, set bootVerbose = true (adds ~1-5MB to journal per suspend cycle)
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dev.johnrinehart.thunderbolt-debug;
in
{
  options.dev.johnrinehart.thunderbolt-debug = {
    enable = lib.mkEnableOption "Thunderbolt/PCI power management debugging";

    bootVerbose = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable verbose PCI/Thunderbolt logging at boot time via kernel command line.
        This will significantly increase journal size during suspend/resume cycles.
        Usually you want to leave this false and enable debugging at runtime when needed.
      '';
    };

    kernelPatches = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Apply kernel patches that add retry logic for PCI power state transitions.
        These fix Thunderbolt DisplayPort tunnel failures after suspend/hibernate.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Kernel config for PCI debugging
    boot.kernelPatches = lib.optionals cfg.kernelPatches [
      # Fix D3cold->D0 transition failures (hibernate resume)
      {
        name = "pci-d3cold-retry";
        patch = ../known_problems/thunderbolt-hibernate-displayport-failure/0001-PCI-Add-retry-logic-for-D3cold-resume.patch;
      }
      # Fix D0->D3hot transition failures (suspend entry)
      {
        name = "pci-d3hot-retry";
        patch = ../known_problems/thunderbolt-hibernate-displayport-failure/0004-PCI-Add-retry-logic-for-D3hot-suspend.patch;
      }
      # Enable PCI debug output (useful with dyndbg)
      {
        name = "pci-debug-config";
        patch = null;
        structuredExtraConfig = with lib.kernel; {
          PCI_DEBUG = yes;
        };
      }
    ];

    # Kernel command line parameters for boot-time verbose logging
    boot.kernelParams = lib.optionals cfg.bootVerbose [
      # Enable dynamic debug for PCI power management, Thunderbolt, ASPM, and PCIe hotplug
      ''dyndbg="file drivers/pci/pci.c +p; file drivers/pci/pcie/aspm.c +p; file drivers/thunderbolt/* +p; file pciehp* +p"''
      "loglevel=7"
    ];

    # Convenience script to enable/disable debug at runtime
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "tb-debug" ''
        set -e
        CONTROL="/proc/dynamic_debug/control"

        case "''${1:-status}" in
          on|enable)
            echo "Enabling PCI/Thunderbolt debug output..."
            echo "file drivers/pci/pci.c +p" | sudo tee $CONTROL > /dev/null
            echo "file drivers/pci/pcie/aspm.c +p" | sudo tee $CONTROL > /dev/null
            echo "module thunderbolt +p" | sudo tee $CONTROL > /dev/null
            echo "file pciehp* +p" | sudo tee $CONTROL > /dev/null
            echo "Debug enabled. Use 'journalctl -kf' to watch output."
            ;;
          off|disable)
            echo "Disabling PCI/Thunderbolt debug output..."
            echo "file drivers/pci/pci.c -p" | sudo tee $CONTROL > /dev/null
            echo "file drivers/pci/pcie/aspm.c -p" | sudo tee $CONTROL > /dev/null
            echo "module thunderbolt -p" | sudo tee $CONTROL > /dev/null
            echo "file pciehp* -p" | sudo tee $CONTROL > /dev/null
            echo "Debug disabled."
            ;;
          status)
            echo "Currently enabled debug points:"
            grep "=p" $CONTROL | grep -E "(pci|thunderbolt|pciehp)" || echo "  (none)"
            ;;
          trace-on)
            echo "Enabling Thunderbolt tracepoints..."
            sudo mount -t tracefs tracefs /sys/kernel/debug/tracing 2>/dev/null || true
            echo 1 | sudo tee /sys/kernel/debug/tracing/events/thunderbolt/enable > /dev/null
            echo "Tracepoints enabled. View with: cat /sys/kernel/debug/tracing/trace"
            ;;
          trace-off)
            echo "Disabling Thunderbolt tracepoints..."
            echo 0 | sudo tee /sys/kernel/debug/tracing/events/thunderbolt/enable > /dev/null
            echo "Tracepoints disabled."
            ;;
          trace)
            cat /sys/kernel/debug/tracing/trace
            ;;
          *)
            echo "Usage: tb-debug [on|off|status|trace-on|trace-off|trace]"
            echo ""
            echo "Commands:"
            echo "  on        Enable dyndbg for PCI/Thunderbolt"
            echo "  off       Disable dyndbg for PCI/Thunderbolt"
            echo "  status    Show currently enabled debug points"
            echo "  trace-on  Enable Thunderbolt tracepoints"
            echo "  trace-off Disable Thunderbolt tracepoints"
            echo "  trace     View trace output"
            exit 1
            ;;
        esac
      '')
    ];
  };
}
