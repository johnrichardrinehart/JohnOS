#!/usr/bin/env bash
set -euo pipefail

target_type=''
device=''
image=''
config_name='rock5c'
auto_confirm=0
mount_dir=''
declare -a copy_specs=()

cleanup() {
  if [[ -n "$mount_dir" && -d "$mount_dir" ]]; then
    if mountpoint -q "$mount_dir"; then
      umount "$mount_dir"
    fi
    rmdir "$mount_dir"
  fi
}

usage() {
  cat <<'EOF'
Usage: rock5c-flash-image --target-type {emmc|sd} [options]

Write a Rock 5C image to the inferred eMMC or SD block device, then grow the
root partition and filesystem to fill the device.

Options:
  --target-type TYPE         Required. One of: emmc, sd
  --device PATH              Override the inferred block device
  --image PATH               Use an existing image instead of building from the flake
  --config NAME              NixOS configuration name (default: rock5c)
  --copy SPEC                Copy a plaintext file into the flashed image
                             Format: SOURCE[:DEST]
                             DEST defaults to SOURCE when SOURCE is absolute
  --yes                      Skip the confirmation prompt
  --help                     Show this message

Examples:
  rock5c-flash-image --target-type emmc
  rock5c-flash-image --target-type sd --image ./result/sd-image.img
  rock5c-flash-image --target-type emmc --copy /boot/age.secret
  rock5c-flash-image --target-type sd --copy /tmp/age.secret:/boot/age.secret
EOF
}

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

require_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    die 'run this script as root'
  fi
}

partition_path() {
  case "$1" in
    *[0-9]) printf '%sp1\n' "$1" ;;
    *) printf '%s1\n' "$1" ;;
  esac
}

infer_device() {
  local want_type match_count match_path sys type_name

  want_type="$1"
  match_count=0
  match_path=''

  for sys in /sys/block/mmcblk*; do
    [[ -e "$sys/device/type" ]] || continue
    type_name="$(<"$sys/device/type")"

    case "$type_name" in
      MMC) [[ "$want_type" == 'emmc' ]] || continue ;;
      SD) [[ "$want_type" == 'sd' ]] || continue ;;
      *) continue ;;
    esac

    match_count=$((match_count + 1))
    match_path="/dev/$(basename "$sys")"
  done

  if [[ "$match_count" -eq 0 ]]; then
    die "could not find an inferred $want_type device under /sys/block/mmcblk*"
  fi

  if [[ "$match_count" -gt 1 ]]; then
    die "found multiple candidate $want_type devices; rerun with --device"
  fi

  printf '%s\n' "$match_path"
}

assert_safe_target() {
  local root_source root_real root_disk mounted_entries

  [[ -b "$device" ]] || die "$device is not a block device"

  root_source="$(findmnt -n -o SOURCE / || true)"
  if [[ -n "$root_source" ]]; then
    root_real="$(readlink -f "$root_source" || true)"
    root_disk="$(lsblk -ndo PKNAME "$root_real" 2>/dev/null || true)"
    if [[ -n "$root_disk" && "/dev/$root_disk" == "$device" ]]; then
      die "refusing to overwrite the disk that backs the current root filesystem ($device)"
    fi
  fi

  mounted_entries="$(lsblk -nrpo PATH,MOUNTPOINT "$device" | awk '$2 != "" { print $0 }')"
  if [[ -n "$mounted_entries" ]]; then
    printf 'Mounted paths on %s:\n%s\n' "$device" "$mounted_entries" >&2
    die 'unmount the target device before flashing it'
  fi
}

build_image() {
  local build_attr out_path

  build_attr='sdImage'
  if [[ "$target_type" == 'emmc' ]]; then
    build_attr='eMMCImage'
  fi

  printf '==> Building %s from nixosConfigurations.%s\n' "$build_attr" "$config_name" >&2
  out_path="$(nix build ".#nixosConfigurations.$config_name.config.system.build.$build_attr" --print-out-paths --no-link)"
  [[ -f "$out_path" ]] || die 'build did not produce an image file'
  printf '%s\n' "$out_path"
}

reread_partition_table() {
  sync
  partprobe "$device" || blockdev --rereadpt "$device" || true
  sleep 2
}

resize_rootfs() {
  local part

  part="$(partition_path "$device")"
  [[ -b "$part" ]] || die "could not find first partition for $device"

  printf '==> Growing partition 1 on %s\n' "$device"
  sfdisk --delete "$device" 1
  printf '32768,,L,*\n' | sfdisk --append "$device"

  reread_partition_table
  [[ -b "$part" ]] || die 'partition 1 disappeared after partition table update'

  printf '==> Checking filesystem on %s\n' "$part"
  e2fsck -fy "$part"

  printf '==> Resizing filesystem on %s\n' "$part"
  resize2fs "$part"
}

parse_copy_spec() {
  local spec src dest

  spec="$1"
  if [[ "$spec" == *:* ]]; then
    src="${spec%%:*}"
    dest="${spec#*:}"
  else
    src="$spec"
    dest="$spec"
  fi

  [[ -n "$src" ]] || die '--copy requires a non-empty source path'
  [[ -f "$src" ]] || die "copy source does not exist or is not a file: $src"
  [[ "$dest" == /* ]] || die "copy destination must be absolute inside the flashed filesystem: $dest"

  printf '%s\t%s\n' "$src" "$dest"
}

install_copy_specs() {
  local part source_file dest_path target_dir spec

  [[ "${#copy_specs[@]}" -gt 0 ]] || return 0

  part="$(partition_path "$device")"
  mount_dir="$(mktemp -d)"
  printf '==> Mounting %s at %s\n' "$part" "$mount_dir"
  mount "$part" "$mount_dir"

  for spec in "${copy_specs[@]}"; do
    IFS=$'\t' read -r source_file dest_path <<<"$spec"
    [[ -n "$source_file" ]] || continue
    target_dir="$mount_dir$(dirname "$dest_path")"
    mkdir -p "$target_dir"
    install -m 600 "$source_file" "$mount_dir$dest_path"
    printf '==> Copied %s to %s\n' "$source_file" "$dest_path"
  done

  cleanup
  mount_dir=''
}

print_plan() {
  local image_size image_size_human spec source_file dest_path

  image_size="$(stat -c%s "$image")"
  image_size_human="$(numfmt --to=iec-i --suffix=B "$image_size")"

  printf '==> Rock 5C flash plan\n'
  printf '    Target type: %s\n' "$target_type"
  printf '    Device:      %s\n' "$device"
  printf '    Image:       %s (%s)\n' "$image" "$image_size_human"

  if [[ "${#copy_specs[@]}" -gt 0 ]]; then
    printf '    Copies:\n'
    for spec in "${copy_specs[@]}"; do
      IFS=$'\t' read -r source_file dest_path <<<"$spec"
      printf '      %s -> %s\n' "$source_file" "$dest_path"
    done
  fi

  printf '\n'
  printf '    WARNING: this will erase all data on %s\n' "$device"
}

trap cleanup EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target-type)
      [[ $# -ge 2 ]] || die '--target-type requires a value'
      target_type="$2"
      shift 2
      ;;
    --device)
      [[ $# -ge 2 ]] || die '--device requires a value'
      device="$2"
      shift 2
      ;;
    --image)
      [[ $# -ge 2 ]] || die '--image requires a value'
      image="$2"
      shift 2
      ;;
    --config)
      [[ $# -ge 2 ]] || die '--config requires a value'
      config_name="$2"
      shift 2
      ;;
    --copy)
      [[ $# -ge 2 ]] || die '--copy requires a value'
      copy_specs+=("$(parse_copy_spec "$2")")
      shift 2
      ;;
    --yes)
      auto_confirm=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

require_root

case "$target_type" in
  emmc|sd) ;;
  *)
    usage
    die '--target-type must be one of: emmc, sd'
    ;;
esac

if [[ -z "$device" ]]; then
  device="$(infer_device "$target_type")"
fi

assert_safe_target

if [[ -z "$image" ]]; then
  image="$(build_image)"
fi

[[ -f "$image" ]] || die "$image does not exist"

print_plan

if [[ "$auto_confirm" -ne 1 ]]; then
  printf '\n'
  read -r -p 'Continue? [y/N] ' confirm
  case "$confirm" in
    y|Y) ;;
    *)
      printf 'Aborted.\n'
      exit 0
      ;;
  esac
fi

printf '\n'
printf '==> Writing image to %s\n' "$device"
dd if="$image" of="$device" bs=4M conv=fsync status=progress

printf '\n'
printf '==> Re-reading partition table\n'
reread_partition_table

printf '\n'
resize_rootfs

printf '\n'
install_copy_specs

printf '\n'
printf '==> Final device layout\n'
lsblk "$device"
