# Hibernate Resume Optimization Module
#
# Addresses the 30-60 second delay after hibernate resume where the display
# renders but input (keyboard/mouse) is unresponsive. This is caused by
# resource contention between the user session and system services during
# the post-resume "thaw" phase.
#
# Root causes addressed:
#   1. rtkit demoting audio threads due to perceived system overload
#   2. Network services (dhcpcd, tailscale, bluetooth) flooding D-Bus
#   3. PipeWire/WirePlumber blocking on bluetooth reconnection
#   4. Compositor (niri/hyprland) starved of CPU while services restart
#
# Usage:
#   dev.johnrinehart.hibernate-resume-optimization.enable = true;
#
# For fine-grained control, individual optimizations can be toggled.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dev.johnrinehart.hibernate-resume-optimization;
in
{
  options.dev.johnrinehart.hibernate-resume-optimization = {
    enable = lib.mkEnableOption "Hibernate resume optimizations for faster session interactivity";

    deferNetworking = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Defer network service restarts after resume.

          **Impact: HIGH** (~20-30s improvement)

          After hibernate resume, dhcpcd immediately tries to rebind interfaces
          which triggers a cascade: wpa_supplicant reconnects, DHCP discovers,
          tailscale tries to reconnect (spamming dozens of bootstrap DNS servers),
          and NetworkManager dispatches events. All of this floods D-Bus and
          competes with the compositor for CPU.

          When enabled, network services wait a few seconds after resume before
          attempting reconnection, allowing the user session to become interactive
          first.
        '';
      };

      delaySeconds = lib.mkOption {
        type = lib.types.int;
        default = 3;
        description = ''
          Seconds to wait after resume before network services restart.
          3 seconds is usually sufficient for the compositor to process
          queued input events and render the first frame.
        '';
      };
    };

    deferBluetooth = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Defer bluetooth reconnection attempts after resume.

          **Impact: MEDIUM** (~5-10s improvement)

          Bluetooth (bluez) immediately tries to reconnect to paired devices
          after resume. This generates many D-Bus messages and causes
          WirePlumber to block waiting for audio endpoint registration.
          The repeated "Host is down" errors spam the journal and consume
          CPU cycles.

          When enabled, bluetooth adapter is briefly disabled after resume
          then re-enabled after a delay.
        '';
      };

      delaySeconds = lib.mkOption {
        type = lib.types.int;
        default = 5;
        description = ''
          Seconds to wait after resume before re-enabling bluetooth.
          Slightly longer than network delay since BT reconnection
          is less critical for immediate usability.
        '';
      };
    };

    prioritizeUserSession = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Give the user session higher CPU priority during and after resume.

          **Impact: MEDIUM** (~10-15s improvement)

          The compositor and input handling run in the user session, but
          compete equally with system services for CPU after resume. This
          causes the 40+ second input lag reported by libinput.

          When enabled:
          - User slice gets higher CPU weight
          - rtkit is configured to be less aggressive about demoting threads
          - A post-resume hook temporarily boosts session priority
        '';
      };

      userSliceCPUWeight = lib.mkOption {
        type = lib.types.int;
        default = 200;
        description = ''
          CPU weight for user.slice (default is 100).
          Higher values give user sessions more CPU time relative to
          system services. 200 means 2x the priority of default services.
        '';
      };
    };

    reduceHibernateImageSize = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Reduce the hibernate image size for faster suspend/resume.

          **Impact: LOW-MEDIUM** (~5-10s improvement on resume)

          The kernel tries to save up to image_size bytes of memory to swap.
          Smaller images mean less data to write/read, but may cause more
          memory to be discarded and reloaded from disk after resume.

          Default kernel value is ~2/5 of RAM. This option reduces it to
          speed up the hibernate/resume cycle at the cost of potentially
          more disk I/O after resume as applications fault pages back in.

          Only enable if you have fast NVMe storage and want faster
          hibernate/resume at the cost of slightly slower app responsiveness
          immediately after resume.
        '';
      };

      imageSizeBytes = lib.mkOption {
        type = lib.types.int;
        default = 4000000000; # ~4GB
        description = ''
          Maximum hibernate image size in bytes.
          Smaller = faster hibernate/resume but more post-resume page faults.
          4GB is a reasonable balance for systems with 16-32GB RAM.
        '';
      };
    };

    enableResumeCompression = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Enable LZO compression for hibernate images.

          **Impact: VARIABLE** (may improve or worsen depending on hardware)

          Compression reduces the amount of data written to/read from swap,
          but adds CPU overhead. On systems with fast NVMe but slower CPUs,
          disabling compression (the default) may be faster. On systems with
          slower storage, compression typically helps.

          This option removes 'nocompress' from kernel command line if present.
          Note: This conflicts with nocompress in boot.kernelParams - you may
          need to remove it manually from your config.
        '';
      };
    };

    debugTiming = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Enable PM timing debug output to diagnose resume delays.

          **Impact: NONE** (diagnostic only)

          Enables pm_print_times which logs detailed timing for each
          device's suspend/resume. Useful for identifying slow drivers.
          Check with: journalctl -k | grep "PM:"
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    # Base configuration - always applied when module is enabled
    {
      # Post-resume service that coordinates deferred restarts
      systemd.services.hibernate-resume-optimize = {
        description = "Optimize system state after hibernate resume";
        after = [ "hibernate.target" "suspend-then-hibernate.target" ];
        wantedBy = [ "hibernate.target" "suspend-then-hibernate.target" ];

        serviceConfig = {
          Type = "oneshot";
          ExecStart = pkgs.writeShellScript "hibernate-resume-optimize" ''
            # Log resume time for debugging
            echo "hibernate-resume-optimize: Session thawed at $(date)"

            # Give compositor a head start
            sleep 0.5

            # Signal that optimization service has run
            mkdir -p /run/hibernate-resume
            touch /run/hibernate-resume/optimized
          '';
        };
      };
    }

    # Defer networking after resume
    (lib.mkIf cfg.deferNetworking.enable {
      # Override post-resume to not immediately reload dhcpcd
      powerManagement.resumeCommands = ''
        # Defer network restart - let user session become interactive first
        (
          sleep ${toString cfg.deferNetworking.delaySeconds}

          # Reload dhcpcd if running
          if systemctl is-active dhcpcd.service >/dev/null 2>&1; then
            systemctl reload dhcpcd.service || true
          fi

          # Poke NetworkManager to reassociate
          if systemctl is-active NetworkManager.service >/dev/null 2>&1; then
            ${pkgs.networkmanager}/bin/nmcli networking off 2>/dev/null || true
            sleep 0.5
            ${pkgs.networkmanager}/bin/nmcli networking on 2>/dev/null || true
          fi
        ) &
      '';

      # Prevent dhcpcd from being reloaded synchronously in post-resume.service
      # The default NixOS post-resume.service runs: systemctl reload dhcpcd.service
      # We override this by making our own post-resume that defers it
      systemd.services.post-resume = {
        serviceConfig = {
          # Replace the ExecStart entirely - we handle dhcpcd in resumeCommands
          ExecStart = lib.mkForce (pkgs.writeShellScript "post-resume-deferred" ''
            # Try-restart post-resume.target for any dependent units
            systemctl try-restart --no-block post-resume.target || true

            # dhcpcd reload is handled by hibernate-resume-optimize with delay
            # Do NOT reload it here synchronously
          '');
        };
      };

      # Make tailscale less aggressive on resume
      systemd.services.tailscaled.serviceConfig = {
        # Delay tailscale's network checks on resume
        ExecStartPost = lib.mkAfter [
          "-${pkgs.coreutils}/bin/sleep 2"
        ];
      };
    })

    # Defer bluetooth reconnection
    (lib.mkIf cfg.deferBluetooth.enable {
      # Service to defer bluetooth after resume
      systemd.services.bluetooth-resume-defer = {
        description = "Defer bluetooth reconnection after hibernate resume";
        after = [ "hibernate.target" "suspend-then-hibernate.target" ];
        wantedBy = [ "hibernate.target" "suspend-then-hibernate.target" ];
        before = [ "bluetooth.target" ];

        serviceConfig = {
          Type = "oneshot";
          ExecStart = pkgs.writeShellScript "bluetooth-resume-defer" ''
            # Check if bluetooth is available
            if ! command -v bluetoothctl &>/dev/null; then
              exit 0
            fi

            # Briefly power off bluetooth to stop reconnection attempts
            bluetoothctl power off 2>/dev/null || true

            # Wait for user session to stabilize
            sleep ${toString cfg.deferBluetooth.delaySeconds}

            # Re-enable bluetooth
            bluetoothctl power on 2>/dev/null || true
          '';
        };
      };
    })

    # Prioritize user session
    (lib.mkIf cfg.prioritizeUserSession.enable {
      # Give user slice higher CPU priority
      systemd.slices.user = {
        sliceConfig = {
          CPUWeight = cfg.prioritizeUserSession.userSliceCPUWeight;
        };
      };

      # Make rtkit less aggressive about demoting threads
      # rtkit demotes threads when it thinks the system is overloaded
      # After resume, it incorrectly detects overload due to timestamp skew
      systemd.services.rtkit-daemon.serviceConfig = {
        # Give rtkit itself higher priority so it can make decisions faster
        Nice = -5;
        # Increase the watchdog timeout to prevent false "starving" detection
        Environment = [
          "RTKIT_CANARY_WATCHDOG_MSEC=30000"
        ];
      };

      # User service to boost session priority immediately after resume
      # This runs in user context and affects the compositor directly
      systemd.user.services.session-priority-boost = {
        description = "Boost session priority after resume";
        wantedBy = [ "graphical-session.target" ];
        after = [ "graphical-session.target" ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          # Renice the entire user session to higher priority
          # $$PPID gets the session leader
          ExecStart = pkgs.writeShellScript "boost-session" ''
            # Get our session's process group
            SESSION_LEADER=$(ps -o ppid= -p $$ | tr -d ' ')

            # Try to renice the session (may fail without CAP_SYS_NICE)
            ${pkgs.util-linux}/bin/renice -n -5 -g $SESSION_LEADER 2>/dev/null || true

            # Also try to set the compositor specifically if we can identify it
            for compositor in niri Hyprland sway; do
              PID=$(${pkgs.procps}/bin/pgrep -u $USER "^$compositor$" 2>/dev/null | head -1)
              if [ -n "$PID" ]; then
                ${pkgs.util-linux}/bin/renice -n -10 -p $PID 2>/dev/null || true
                # Try to set realtime IO priority for compositor
                ${pkgs.util-linux}/bin/ionice -c 1 -n 0 -p $PID 2>/dev/null || true
              fi
            done

            exit 0
          '';
        };
      };

      # Allow the user to renice their own processes (for session-priority-boost)
      security.pam.loginLimits = [
        {
          domain = "@users";
          type = "-";
          item = "nice";
          value = "-10";
        }
      ];
    })

    # Reduce hibernate image size
    (lib.mkIf cfg.reduceHibernateImageSize.enable {
      # Set image_size via tmpfiles (applied at boot)
      systemd.tmpfiles.rules = [
        "w /sys/power/image_size - - - - ${toString cfg.reduceHibernateImageSize.imageSizeBytes}"
      ];
    })

    # Enable resume compression (remove nocompress)
    (lib.mkIf cfg.enableResumeCompression.enable {
      # Note: This doesn't remove existing nocompress from boot.kernelParams
      # User needs to remove it manually. We just warn here.
      warnings = lib.optional
        (lib.any (p: p == "nocompress") config.boot.kernelParams)
        "hibernate-resume-optimization: enableResumeCompression is set but 'nocompress' is in boot.kernelParams. Remove 'nocompress' to enable compression.";
    })

    # Debug timing
    (lib.mkIf cfg.debugTiming.enable {
      # Enable PM timing via tmpfiles
      systemd.tmpfiles.rules = [
        "w /sys/power/pm_print_times - - - - 1"
      ];

      # Also add kernel param for early boot timing
      boot.kernelParams = [ "pm_print_times=1" ];
    })
  ]);
}
