{
  lib,
  writeShellScriptBin,
  libnotify,
  procps,
  onIdlePackage, # The exact on-idle package
}:

writeShellScriptBin "kill-idle-group" ''
  # Define a recursive function to kill a process and all its descendants
  kill_process_tree() {
    local PARENT_PID=$1

    # Find all immediate children
    local CHILD_PIDS=$(${lib.getExe' procps "pgrep"} -P $PARENT_PID 2>/dev/null)

    # Recursively kill all children first (depth-first)
    if [ -n "$CHILD_PIDS" ]; then
      for CHILD_PID in $CHILD_PIDS; do
        kill_process_tree $CHILD_PID
      done
    fi

    # Kill the process itself after killing all children
    kill -TERM $PARENT_PID 2>/dev/null || true
  }

  # Get the exact binary path from the package
  ON_IDLE_BIN="${lib.getExe onIdlePackage}"

  # Find any running processes that match the exact binary path
  ON_IDLE_PIDS=$(${lib.getExe' procps "pgrep"} -f "$ON_IDLE_BIN")

  # Kill each on-idle process and its descendants
  if [ -n "$ON_IDLE_PIDS" ]; then
    for PID in $ON_IDLE_PIDS; do
      kill_process_tree $PID
    done
  fi

  # Show welcome back notification at the end
  ${lib.getExe libnotify} -u normal "Welcome back!"
''
