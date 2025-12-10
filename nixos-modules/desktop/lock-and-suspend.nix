{ pkgs }:
pkgs.writeShellScriptBin "lock-and-suspend" ''
  ${pkgs.systemd}/bin/loginctl lock-session && \
  ${pkgs.systemd}/bin/systemctl suspend-then-hibernate
''
