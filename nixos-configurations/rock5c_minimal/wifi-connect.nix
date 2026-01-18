{
  pkgs ? import <nixpkgs> { },
}:
pkgs.writeShellApplication {
  name = "wifi-connect";

  runtimeInputs = with pkgs; [
    wpa_supplicant
    systemd
    coreutils
  ];

  text = ''
    set -euo pipefail

    INTERFACE="''${1:-wlan0}"

    if [ ! -d "/sys/class/net/''$INTERFACE" ]; then
      echo "Error: Interface ''$INTERFACE does not exist"
      echo "Available interfaces:"
      ls /sys/class/net/
      exit 1
    fi

    echo "==> Wi-Fi Setup for ''$INTERFACE"
    echo ""

    read -rp "SSID: " SSID
    if [ -z "''$SSID" ]; then
      echo "Error: SSID cannot be empty"
      exit 1
    fi

    read -rsp "Password: " PASSWORD
    echo ""
    if [ -z "''$PASSWORD" ]; then
      echo "Error: Password cannot be empty"
      exit 1
    fi

    CONFIG_FILE="/tmp/wpa_supplicant_''$INTERFACE.conf"

    echo "==> Generating wpa_supplicant config..."
    wpa_passphrase "''$SSID" "''$PASSWORD" > "''$CONFIG_FILE"
    chmod 600 "''$CONFIG_FILE"

    # Kill any existing wpa_supplicant for this interface
    echo "==> Stopping any existing wpa_supplicant on ''$INTERFACE..."
    pkill -f "wpa_supplicant.*''$INTERFACE" || true
    sleep 1

    echo "==> Bringing up ''$INTERFACE..."
    ip link set "''$INTERFACE" up

    echo "==> Starting wpa_supplicant..."
    wpa_supplicant -B -i "''$INTERFACE" -c "''$CONFIG_FILE"

    echo "==> Waiting for association..."
    for i in $(seq 1 10); do
      if iw dev "''$INTERFACE" link 2>/dev/null | grep -q "Connected"; then
        echo "    Connected!"
        break
      fi
      sleep 1
      echo "    Attempt ''$i/10..."
    done

    echo "==> Requesting DHCP lease..."
    networkctl renew "''$INTERFACE" || true

    sleep 2

    echo ""
    echo "==> Status:"
    ip addr show "''$INTERFACE"
  '';
}
