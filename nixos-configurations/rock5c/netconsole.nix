{ pkgs, lib, ... }:
let
  netconsoleDevice = "wlan0";
  netconsoleTargetIP = "172.16.0.3";
  netconsoleTargetMAC = "f4:7b:09:9b:69:0f";
  netconsoleSourcePort = 6665;
  netconsoleTargetPort = 6666;
in
{
  boot.extraModprobeConfig =
    lib.mkAfter "options netconsole netconsole=${toString netconsoleSourcePort}@/${netconsoleDevice},${toString netconsoleTargetPort}@${netconsoleTargetIP}/${netconsoleTargetMAC}";

  systemd.services.netconsole-online = {
    description = "Enable netconsole after network is online";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    path = [ pkgs.kmod pkgs.iproute2 pkgs.coreutils ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -e
      for _ in $(seq 1 20); do
        if ${pkgs.iproute2}/bin/ip -4 -br addr show ${netconsoleDevice} 2>/dev/null | ${pkgs.gnugrep}/bin/grep -Eq '([0-9]{1,3}\.){3}[0-9]{1,3}/'; then
          break
        fi
        ${pkgs.coreutils}/bin/sleep 2
      done
      ${pkgs.iproute2}/bin/ip -4 -br addr show ${netconsoleDevice} | ${pkgs.gnugrep}/bin/grep -Eq '([0-9]{1,3}\.){3}[0-9]{1,3}/'
      ${pkgs.kmod}/bin/modprobe -r netconsole 2>/dev/null || true
      ${pkgs.kmod}/bin/modprobe netconsole
    '';
  };
}
