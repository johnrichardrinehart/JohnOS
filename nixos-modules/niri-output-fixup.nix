# Compositor-level safety net for MST downstream monitors with missing EDID after hibernate resume.
#
# After hibernate resume on a Framework 13 with Thunderbolt daisy-chained Dell monitors,
# the DP MST downstream monitor (Dell U2520D) often connects with missing EDID, appearing
# as "Unknown Unknown Unknown" in Niri. Niri's config matching requires make/model/serial,
# so the output gets auto-placed at the wrong position, breaking cursor adjacency.
#
# This service detects Unknown outputs, matches them by resolution to expected configs,
# and repositions them. It also restarts hyprpaper so wallpapers render correctly.
#
# REMOVAL CONDITION: Remove once the kernel reliably provides EDID for all MST downstream
# devices after hibernate resume (i.e., `niri msg outputs` never shows "Unknown" for
# monitors that have valid EDID on fresh boot).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dev.johnrinehart.niri-output-fixup;

  expectedOutputsJSON = builtins.toJSON cfg.expectedOutputs;

  fixupScript = pkgs.writeShellScript "niri-output-fixup" ''
    set -euo pipefail

    EXPECTED_OUTPUTS='${expectedOutputsJSON}'

    log_info()  { logger -t niri-output-fixup "INFO: $*"; }
    log_warn()  { logger -t niri-output-fixup "WARN: $*"; }
    log_error() { logger -t niri-output-fixup "ERROR: $*"; }

    wait_for_niri() {
      local attempts=0
      local max_attempts=30
      while [ "$attempts" -lt "$max_attempts" ]; do
        if niri msg --json outputs >/dev/null 2>&1; then
          log_info "niri socket responding after ''${attempts}s"
          return 0
        fi
        attempts=$((attempts + 1))
        sleep 1
      done
      log_error "niri socket not responding after ''${max_attempts}s"
      return 1
    }

    # Try to force kernel-level re-detection for a connector via sysfs.
    # This triggers drm_dp_mst_detect_port() which re-reads EDID if
    # the cached copy is NULL (e.g. after failed initial read).
    try_sysfs_redetect() {
      local connector="$1"
      local sysfs_path="/sys/class/drm/card0-''${connector}/status"

      if [ ! -f "$sysfs_path" ]; then
        # Try card1 as fallback
        sysfs_path="/sys/class/drm/card1-''${connector}/status"
      fi

      if [ -f "$sysfs_path" ]; then
        log_info "forcing kernel re-detect for $connector via $sysfs_path"
        echo detect | tee "$sysfs_path" >/dev/null 2>&1 || {
          log_warn "sysfs re-detect failed for $connector (permission denied?)"
          return 1
        }
        # Give kernel time to re-read EDID via sideband
        sleep 2
        return 0
      else
        log_warn "sysfs status not found for $connector"
        return 1
      fi
    }

    check_and_fix() {
      local outputs
      outputs=$(niri msg --json outputs) || {
        log_error "failed to query niri outputs"
        return 1
      }

      # First pass: try sysfs re-detect for Unknown outputs
      local unknown_connectors=""
      local num_outputs
      num_outputs=$(echo "$outputs" | jq 'length')

      local i=0
      while [ "$i" -lt "$num_outputs" ]; do
        local make model connector
        make=$(echo "$outputs" | jq -r ".[$i].make")
        model=$(echo "$outputs" | jq -r ".[$i].model")
        connector=$(echo "$outputs" | jq -r ".[$i].name")

        if [ "$make" = "Unknown" ] && [ "$model" = "Unknown" ]; then
          log_info "detected Unknown output $connector, attempting kernel re-detect"
          if try_sysfs_redetect "$connector"; then
            unknown_connectors="$unknown_connectors $connector"
          fi
        fi
        i=$((i + 1))
      done

      # If we triggered any re-detects, re-read outputs to see if EDID recovered
      if [ -n "$unknown_connectors" ]; then
        log_info "re-reading outputs after sysfs re-detect"
        sleep 1
        outputs=$(niri msg --json outputs) || {
          log_error "failed to re-query niri outputs after re-detect"
          return 1
        }
      fi

      # Second pass: reposition any outputs still showing as Unknown
      local repositioned=0
      num_outputs=$(echo "$outputs" | jq 'length')

      i=0
      while [ "$i" -lt "$num_outputs" ]; do
        local make model connector current_x current_y mode_width mode_height
        make=$(echo "$outputs" | jq -r ".[$i].make")
        model=$(echo "$outputs" | jq -r ".[$i].model")
        connector=$(echo "$outputs" | jq -r ".[$i].name")

        if [ "$make" = "Unknown" ] && [ "$model" = "Unknown" ]; then
          # Get current mode resolution
          mode_width=$(echo "$outputs" | jq -r ".[$i].currentMode.width // .[$i].modes[] | select(.isCurrent == true) | .width // empty" 2>/dev/null)
          mode_height=$(echo "$outputs" | jq -r ".[$i].currentMode.height // .[$i].modes[] | select(.isCurrent == true) | .height // empty" 2>/dev/null)

          # Try alternative JSON paths if the above didn't work
          if [ -z "$mode_width" ] || [ -z "$mode_height" ]; then
            mode_width=$(echo "$outputs" | jq -r "
              .[$i] |
              if .currentMode then .currentMode.width
              elif .modes then (.modes[] | select(.isCurrent == true) | .width)
              else empty end
            " 2>/dev/null)
            mode_height=$(echo "$outputs" | jq -r "
              .[$i] |
              if .currentMode then .currentMode.height
              elif .modes then (.modes[] | select(.isCurrent == true) | .height)
              else empty end
            " 2>/dev/null)
          fi

          if [ -z "$mode_width" ] || [ -z "$mode_height" ]; then
            log_warn "could not determine resolution for Unknown output $connector"
            i=$((i + 1))
            continue
          fi

          # Get current position
          current_x=$(echo "$outputs" | jq -r ".[$i].logical.x // .[$i].position.x // 0")
          current_y=$(echo "$outputs" | jq -r ".[$i].logical.y // .[$i].position.y // 0")

          log_info "Unknown output $connector (after re-detect): ''${mode_width}x''${mode_height} at ''${current_x},''${current_y}"

          # Match against expected outputs by resolution
          local num_expected
          num_expected=$(echo "$EXPECTED_OUTPUTS" | jq 'length')
          local j=0
          while [ "$j" -lt "$num_expected" ]; do
            local exp_w exp_h exp_x exp_y
            exp_w=$(echo "$EXPECTED_OUTPUTS" | jq -r ".[$j].width")
            exp_h=$(echo "$EXPECTED_OUTPUTS" | jq -r ".[$j].height")
            exp_x=$(echo "$EXPECTED_OUTPUTS" | jq -r ".[$j].x")
            exp_y=$(echo "$EXPECTED_OUTPUTS" | jq -r ".[$j].y")

            if [ "$mode_width" = "$exp_w" ] && [ "$mode_height" = "$exp_h" ]; then
              if [ "$current_x" != "$exp_x" ] || [ "$current_y" != "$exp_y" ]; then
                log_info "repositioning $connector from ''${current_x},''${current_y} to ''${exp_x},''${exp_y}"
                if niri msg action output "$connector" position set "$exp_x" "$exp_y"; then
                  log_info "successfully repositioned $connector"
                  repositioned=$((repositioned + 1))
                else
                  log_error "failed to reposition $connector"
                fi
              else
                log_info "$connector already at correct position ''${exp_x},''${exp_y}"
              fi
              break
            fi
            j=$((j + 1))
          done

          if [ "$j" -eq "$num_expected" ]; then
            log_warn "no expected output matches resolution ''${mode_width}x''${mode_height} for $connector"
          fi
        fi
        i=$((i + 1))
      done

      if [ "$repositioned" -gt 0 ]; then
        log_info "repositioned $repositioned output(s), restarting hyprpaper"
        # Give niri a moment to settle after repositioning
        sleep 1
        if pkill hyprpaper 2>/dev/null; then
          sleep 0.5
        fi
        hyprpaper &
        disown
        log_info "hyprpaper restarted"
      fi
    }

    main_loop() {
      wait_for_niri || exit 1

      # Initial check
      check_and_fix

      # Watch for output changes via niri event stream
      log_info "watching for WorkspacesChanged events"
      niri msg --json event-stream 2>/dev/null | while IFS= read -r event; do
        if echo "$event" | jq -e '.WorkspacesChanged' >/dev/null 2>&1; then
          log_info "WorkspacesChanged event received, re-checking outputs"
          # Small delay to let outputs settle
          sleep 2
          check_and_fix
        fi
      done

      log_warn "event stream ended, exiting"
    }

    main_loop
  '';
in
{
  options.dev.johnrinehart.niri-output-fixup = {
    enable = lib.mkEnableOption "niri output fixup for Unknown MST monitors after hibernate resume";

    expectedOutputs = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          width = lib.mkOption {
            type = lib.types.int;
            description = "Expected mode width in pixels";
          };
          height = lib.mkOption {
            type = lib.types.int;
            description = "Expected mode height in pixels";
          };
          x = lib.mkOption {
            type = lib.types.int;
            description = "Expected X position";
          };
          y = lib.mkOption {
            type = lib.types.int;
            description = "Expected Y position";
          };
        };
      });
      default = [];
      description = "List of expected outputs to match Unknown monitors against by resolution";
      example = [
        { width = 2560; height = 1440; x = 3840; y = 360; }
      ];
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.niri-output-fixup = {
      description = "Fix niri output positions for Unknown MST monitors after hibernate resume";
      wantedBy = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];

      path = [
        pkgs.niri
        pkgs.jq
        pkgs.hyprpaper
        pkgs.coreutils
        pkgs.util-linux  # logger
        pkgs.procps       # pkill
      ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${fixupScript}";
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
  };
}
