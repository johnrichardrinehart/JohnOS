{
  pkgs,
  lib,
  niri,
}:
pkgs.writeShellScriptBin "niri-gather-windows" ''
  set -euo pipefail

  # Get current output from focused workspace
  current_output=$(${lib.getExe niri} msg --json workspaces | ${lib.getExe pkgs.jq} -r '.[] | select(.is_focused) | .output')

  if [ -z "$current_output" ]; then
    echo "Error: Could not determine current output" >&2
    exit 1
  fi

  # Build a map of workspace_id -> output
  ws_to_output=$(${lib.getExe niri} msg --json workspaces | ${lib.getExe pkgs.jq} -r 'map({(.id|tostring): .output}) | add')

  # Get all window IDs not on the current output
  window_ids=$(${lib.getExe niri} msg --json windows | ${lib.getExe pkgs.jq} -r --argjson ws_map "$ws_to_output" --arg current "$current_output" '
    .[] | select($ws_map[.workspace_id|tostring] != $current) | .id
  ')

  if [ -z "$window_ids" ]; then
    echo "All windows are already on $current_output"
    exit 0
  fi

  # Move each window to current output
  for id in $window_ids; do
    ${lib.getExe niri} msg action move-window-to-monitor --id "$id" "$current_output"
  done

  echo "Moved windows to $current_output"
''
