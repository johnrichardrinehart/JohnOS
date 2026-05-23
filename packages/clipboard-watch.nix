{
  lib,
  wl-clipboard,
  writeShellScriptBin,
  clipboard-store-notify,
}:

writeShellScriptBin "clipboard-watch" ''
  set -euo pipefail

  wl_paste=${lib.getExe' wl-clipboard "wl-paste"}

  $wl_paste --watch ${lib.getExe clipboard-store-notify}
''
