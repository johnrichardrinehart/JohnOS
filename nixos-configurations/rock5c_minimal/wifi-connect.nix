{
  pkgs ? import <nixpkgs> { },
}:
pkgs.writeShellApplication {
  name = "wifi-connect";

  runtimeInputs = with pkgs; [
    iwd
    systemd
    coreutils
    iproute2
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

    echo "==> Wi-Fi Setup for ''$INTERFACE (using iwd)"
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

    # Ensure iwd is running
    echo "==> Starting iwd service..."
    systemctl start iwd.service || true
    sleep 1

    echo "==> Bringing up ''$INTERFACE..."
    ip link set "''$INTERFACE" up

    echo "==> Scanning for networks..."
    iwctl station "''$INTERFACE" scan
    sleep 2

    echo "==> Connecting to ''$SSID..."
    # iwd stores the passphrase, use expect-style input or iwctl's passphrase agent
    # For non-interactive use, we can create the network config directly
    IWD_DIR="/var/lib/iwd"
    mkdir -p "''$IWD_DIR"

    # Create network config file (SSID with special chars needs encoding, but simple SSIDs work as-is)
    # For PSK networks, iwd expects the file to be named SSID.psk
    CONFIG_FILE="''$IWD_DIR/''$SSID.psk"
    cat > "''$CONFIG_FILE" <<EOF
[Security]
Passphrase=''$PASSWORD
EOF
    chmod 600 "''$CONFIG_FILE"

    echo "==> Network config written to ''$CONFIG_FILE"

    # Connect using iwctl
    iwctl station "''$INTERFACE" connect "''$SSID" || true

    echo "==> Waiting for association..."
    for i in $(seq 1 10); do
      if iwctl station "''$INTERFACE" show 2>/dev/null | grep -q "connected"; then
        echo "    Connected!"
        break
      fi
      sleep 1
      echo "    Attempt ''$i/10..."
    done

    # Ensure systemd-networkd picks up the interface
    echo "==> Ensuring systemd-networkd manages the interface..."
    networkctl reload || true
    sleep 1

    echo "==> Requesting DHCP lease..."
    networkctl renew "''$INTERFACE" || true

    sleep 2

    echo ""
    echo "==> Status:"
    iwctl station "''$INTERFACE" show
    echo ""
    ip addr show "''$INTERFACE"
  '';
}
