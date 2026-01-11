# Thunderbolt DP Tunnel Rescan Module
#
# Adds kernel patches that:
# 1. Provide a debugfs interface to manually trigger DP tunnel re-discovery
# 2. Fix the resume path to automatically re-discover DP resources (software CM)
# 3. Re-scan for lost Thunderbolt devices after resume (software CM)
# 4. Add port reset and retry logic when device init fails with EIO (software CM)
# 5. Add ICM (firmware) mode retry logic for device re-enumeration after hibernate
#
# This is useful for recovering USB4/Thunderbolt DisplayPort tunnels after
# hibernate (S4), suspend (S3), or runtime suspend (D3hot/D3cold) when
# the tunnel state becomes inconsistent or devices fail to re-enumerate.
#
# Background:
# There are two Thunderbolt connection manager modes:
# - Software CM (tb.c): Kernel handles all device enumeration
# - ICM (icm.c): Intel firmware handles device enumeration
#
# Most modern Intel systems use ICM. Patch 0006 adds automatic retry logic
# for ICM mode: after hibernate, if devices are still missing after 500ms,
# the driver will retry up to 3 times with increasing delays (1s, 2s, 3s).
#
# Usage:
#   dev.johnrinehart.thunderbolt-dp-rescan.enable = true;
#   dev.johnrinehart.thunderbolt-dp-rescan.debug = true;  # Optional: verbose logging
#
# When enabled:
#   - Kernel is patched with DP tunnel recovery and device rescan fixes
#   - A debugfs interface is available at /sys/kernel/debug/thunderbolt/0-0/dp_rescan
#   - A helper script 'tb-dp-rescan' is installed
#
# Manual usage:
#   # Force DP tunnel re-discovery
#   echo 1 | sudo tee /sys/kernel/debug/thunderbolt/0-0/dp_rescan
#
#   # Or use the helper script
#   tb-dp-rescan
#
# The automatic fixes in patches should handle most cases without manual
# intervention. The debugfs interface is for debugging or edge cases.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dev.johnrinehart.thunderbolt-dp-rescan;

  tbDpRescanScript = pkgs.writeShellScriptBin "tb-dp-rescan" ''
    set -e

    DEBUGFS_TB="/sys/kernel/debug/thunderbolt"

    usage() {
      cat <<EOF
Usage: tb-dp-rescan [OPTIONS] [DOMAIN]

Force re-discovery of DisplayPort tunnels on Thunderbolt/USB4 controllers.

Options:
  -r, --release     Release all DP tunnels instead of rescanning
  -l, --list        List available Thunderbolt domains
  -h, --help        Show this help message

Arguments:
  DOMAIN            Domain to rescan (e.g., 0-0). Default: auto-detect first domain

Examples:
  tb-dp-rescan              # Rescan DP resources on first domain
  tb-dp-rescan 0-0          # Rescan DP resources on domain 0-0
  tb-dp-rescan --release    # Release all DP tunnels
  tb-dp-rescan --list       # List available domains

Note: Requires root privileges (uses sudo automatically).
EOF
      exit 0
    }

    find_first_domain() {
      for dir in "$DEBUGFS_TB"/*/; do
        domain=$(basename "$dir")
        # Look for root switches (format: X-0)
        if [[ "$domain" =~ ^[0-9]+-0$ ]]; then
          if [[ -f "$dir/dp_rescan" ]]; then
            echo "$domain"
            return 0
          fi
        fi
      done
      return 1
    }

    list_domains() {
      echo "Available Thunderbolt domains with DP rescan support:"
      echo ""
      for dir in "$DEBUGFS_TB"/*/; do
        domain=$(basename "$dir")
        if [[ -f "$dir/dp_rescan" ]]; then
          echo "  $domain"
        fi
      done
    }

    # Parse arguments
    CMD="1"  # Default: rescan
    DOMAIN=""

    while [[ $# -gt 0 ]]; do
      case "$1" in
        -h|--help)
          usage
          ;;
        -r|--release)
          CMD="release"
          shift
          ;;
        -l|--list)
          list_domains
          exit 0
          ;;
        -*)
          echo "Unknown option: $1" >&2
          exit 1
          ;;
        *)
          DOMAIN="$1"
          shift
          ;;
      esac
    done

    # Auto-detect domain if not specified
    if [[ -z "$DOMAIN" ]]; then
      DOMAIN=$(find_first_domain) || {
        echo "Error: Could not find a Thunderbolt domain with DP rescan support." >&2
        echo "Check if the kernel patches are applied and debugfs is mounted." >&2
        exit 1
      }
    fi

    RESCAN_FILE="$DEBUGFS_TB/$DOMAIN/dp_rescan"

    if [[ ! -f "$RESCAN_FILE" ]]; then
      echo "Error: dp_rescan file not found for domain $DOMAIN" >&2
      echo "File expected at: $RESCAN_FILE" >&2
      exit 1
    fi

    if [[ "$CMD" == "release" ]]; then
      echo "Releasing all DP tunnels on domain $DOMAIN..."
    else
      echo "Forcing DP tunnel re-discovery on domain $DOMAIN..."
    fi

    if echo "$CMD" | sudo tee "$RESCAN_FILE" > /dev/null; then
      echo "Done."
    else
      echo "Failed to trigger DP rescan" >&2
      exit 1
    fi
  '';
in
{
  options.dev.johnrinehart.thunderbolt-dp-rescan = {
    enable = lib.mkEnableOption "Thunderbolt DP tunnel rescan fixes and debugfs interface";
    debug = lib.mkEnableOption "Enable dynamic debug for thunderbolt driver (verbose logging)";
  };

  config = lib.mkIf cfg.enable {
    # Enable dynamic debug for thunderbolt driver if requested
    boot.kernelParams = lib.mkIf cfg.debug [
      # Enable all thunderbolt debug messages at boot
      # This ensures ICM retry messages and other debug output appear in dmesg
      ''dyndbg="file drivers/thunderbolt/* +p"''
    ];

    boot.kernelPatches = [
      {
        name = "thunderbolt-dp-rescan-debugfs";
        patch = ../known_problems/thunderbolt-dp-rescan/0001-thunderbolt-Add-debugfs-interface-to-force-DP-tunnel.patch;
      }
      {
        name = "thunderbolt-dp-resume-fix";
        patch = ../known_problems/thunderbolt-dp-rescan/0002-thunderbolt-Re-discover-DP-resources-after-resume.patch;
      }
      {
        name = "thunderbolt-rescan-lost-devices";
        patch = ../known_problems/thunderbolt-dp-rescan/0003-thunderbolt-Re-scan-for-lost-devices-after-resume.patch;
      }
      {
        name = "thunderbolt-port-reset-retry";
        patch = ../known_problems/thunderbolt-dp-rescan/0004-thunderbolt-Add-port-reset-and-retry-logic-for-faile.patch;
      }
      {
        name = "thunderbolt-switch-rescan-debugfs";
        patch = ../known_problems/thunderbolt-dp-rescan/0005-thunderbolt-Add-tb_switch_rescan-and-use-it-in-debug.patch;
      }
      {
        name = "thunderbolt-icm-retry-and-rescan";
        patch = ../known_problems/thunderbolt-dp-rescan/0006-thunderbolt-Add-ICM-retry-logic-and-dp_rescan-suppor.patch;
      }
    ];

    environment.systemPackages = [
      tbDpRescanScript
    ];
  };
}
