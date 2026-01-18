{
  pkgs ? import <nixpkgs> { },
}:
pkgs.writeShellApplication {
  name = "resize-sd";

  runtimeInputs = with pkgs; [
    util-linux
    e2fsprogs
    parted
  ];

  text = ''
    set -euo pipefail

    usage() {
      echo "Usage: resize-sd <block-device>"
      echo ""
      echo "Resize the first partition of a Rock 5C SD card image to fill the disk."
      echo "The partition must start at sector 32768 (0x8000) as per the sdImage layout."
      echo ""
      echo "Example: resize-sd /dev/sda"
      exit 1
    }

    if [ $# -ne 1 ]; then
      usage
    fi

    DEVICE="''$1"

    if [ ! -b "''$DEVICE" ]; then
      echo "Error: ''$DEVICE is not a block device"
      exit 1
    fi

    PART="''${DEVICE}1"
    if [ ! -b "''$PART" ]; then
      # Handle nvme style naming (nvme0n1p1)
      PART="''${DEVICE}p1"
      if [ ! -b "''$PART" ]; then
        echo "Error: Cannot find partition 1 on ''$DEVICE"
        exit 1
      fi
    fi

    echo "==> Resizing partition table on ''$DEVICE"
    echo "    Partition ''$PART will be expanded to fill the disk"
    echo ""
    read -rp "Continue? [y/N] " confirm
    if [ "''$confirm" != "y" ] && [ "''$confirm" != "Y" ]; then
      echo "Aborted."
      exit 0
    fi

    # Delete and recreate partition 1 starting at sector 32768
    # This preserves data since only the end sector changes
    echo ""
    echo "==> Recreating partition with start sector 32768..."
    sfdisk --delete "''$DEVICE" 1
    echo "32768,,L,*" | sfdisk --append "''$DEVICE"

    # Force kernel to re-read partition table
    echo ""
    echo "==> Re-reading partition table..."
    partprobe "''$DEVICE" || blockdev --rereadpt "''$DEVICE" || true
    sleep 1

    # Check filesystem
    echo ""
    echo "==> Checking filesystem on ''$PART..."
    e2fsck -f "''$PART"

    # Resize filesystem
    echo ""
    echo "==> Resizing filesystem on ''$PART..."
    resize2fs "''$PART"

    echo ""
    echo "==> Done! Partition and filesystem resized successfully."
    lsblk "''$DEVICE"
  '';
}
