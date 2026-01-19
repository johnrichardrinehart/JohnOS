{
  pkgs ? import <nixpkgs> { },
}:
pkgs.writeShellApplication {
  name = "provision-sd";

  runtimeInputs = with pkgs; [
    util-linux
    e2fsprogs
    parted
    age
    coreutils
    nix
  ];

  text = ''
    set -euo pipefail

    usage() {
      echo "Usage: provision-sd <block-device> [sd-image]"
      echo ""
      echo "Provision a Rock 5C SD card:"
      echo "  1. Write the SD image to the block device"
      echo "  2. Resize the first partition to fill the disk"
      echo "  3. Optionally copy an age secret key to /boot/age.secret"
      echo ""
      echo "Arguments:"
      echo "  block-device  Target device (e.g., /dev/sda)"
      echo "  sd-image      Path to SD image (default: builds from flake)"
      echo ""
      echo "The partition must start at sector 32768 (0x8000) as per the sdImage layout."
      echo ""
      echo "Example: provision-sd /dev/sda"
      echo "         provision-sd /dev/sda ./my-image.img"
      exit 1
    }

    if [ $# -lt 1 ] || [ $# -gt 2 ]; then
      usage
    fi

    DEVICE="''$1"

    if [ ! -b "''$DEVICE" ]; then
      echo "Error: ''$DEVICE is not a block device"
      exit 1
    fi

    # Find SD image
    if [ $# -eq 2 ]; then
      IMAGE="''$2"
      if [ ! -f "''$IMAGE" ]; then
        echo "Error: ''$IMAGE does not exist or is not a file"
        exit 1
      fi
    else
      echo "==> Building SD image..."
      IMAGE=$(nix build .#nixosConfigurations.rock5c_minimal.config.system.build.sdImage --print-out-paths --no-link)
      if [ ! -f "''$IMAGE" ]; then
        echo "Error: Build did not produce an image file"
        exit 1
      fi
      echo "    Built: ''$IMAGE"
    fi

    IMAGE_SIZE=$(stat -c%s "''$IMAGE")
    IMAGE_SIZE_HUMAN=$(numfmt --to=iec-i --suffix=B "''$IMAGE_SIZE")

    echo "==> Provisioning Rock 5C SD card"
    echo "    Device: ''$DEVICE"
    echo "    Image:  ''$IMAGE (''$IMAGE_SIZE_HUMAN)"
    echo ""
    echo "    WARNING: This will ERASE ALL DATA on ''$DEVICE!"
    echo ""
    read -rp "Continue? [y/N] " confirm
    if [ "''$confirm" != "y" ] && [ "''$confirm" != "Y" ]; then
      echo "Aborted."
      exit 0
    fi

    # Write the image
    echo ""
    echo "==> Writing SD image to ''$DEVICE..."
    dd if="''$IMAGE" of="''$DEVICE" bs=4M conv=fsync status=progress

    # Force kernel to re-read partition table
    echo ""
    echo "==> Re-reading partition table..."
    sync
    partprobe "''$DEVICE" || blockdev --rereadpt "''$DEVICE" || true
    sleep 2

    # Find partition
    PART="''${DEVICE}1"
    if [ ! -b "''$PART" ]; then
      # Handle nvme style naming (nvme0n1p1)
      PART="''${DEVICE}p1"
      if [ ! -b "''$PART" ]; then
        echo "Error: Cannot find partition 1 on ''$DEVICE"
        exit 1
      fi
    fi

    # Delete and recreate partition 1 starting at sector 32768
    # This preserves data since only the end sector changes
    echo ""
    echo "==> Resizing partition to fill disk..."
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
    echo "==> Partition and filesystem resized successfully."
    lsblk "''$DEVICE"

    # Provision age secret key
    echo ""
    echo "==> Age secret key provisioning"
    echo "    This key is used by sops-nix to decrypt secrets (e.g., WiFi credentials)"
    echo ""
    read -rp "Path to age secret key file (leave empty to skip): " AGE_KEY_PATH

    if [ -n "''$AGE_KEY_PATH" ]; then
      if [ ! -f "''$AGE_KEY_PATH" ]; then
        echo "Error: ''$AGE_KEY_PATH does not exist"
        exit 1
      fi

      # Validate it looks like an age key
      if ! grep -q "^AGE-SECRET-KEY-" "''$AGE_KEY_PATH"; then
        echo "Error: ''$AGE_KEY_PATH does not appear to be a valid age secret key"
        exit 1
      fi

      # Mount the partition
      MOUNT_DIR=$(mktemp -d)
      echo ""
      echo "==> Mounting ''$PART to ''$MOUNT_DIR..."
      mount "''$PART" "''$MOUNT_DIR"

      # Copy the key
      echo "==> Copying age key to ''$MOUNT_DIR/boot/age.secret..."
      mkdir -p "''$MOUNT_DIR/boot"
      cp "''$AGE_KEY_PATH" "''$MOUNT_DIR/boot/age.secret"
      chmod 600 "''$MOUNT_DIR/boot/age.secret"

      # Unmount
      echo "==> Unmounting..."
      umount "''$MOUNT_DIR"
      rmdir "''$MOUNT_DIR"

      echo ""
      echo "==> Age key provisioned successfully."
    else
      echo "==> Skipping age key provisioning."
    fi

    echo ""
    echo "==> Done! SD card is ready for use."
  '';
}
