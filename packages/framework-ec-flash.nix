{
  lib,
  writeShellApplication,
  coreutils,
  diffutils,
  framework-ec,
  frameworkTool,
  systemd,
  sudo,
}:

writeShellApplication {
  name = "framework-ec-flash";

  runtimeInputs = [
    coreutils
    diffutils
    frameworkTool
    systemd
    sudo
  ];

  text = ''
    set -euo pipefail

    default_image="${framework-ec}/${framework-ec.imagePath or "share/framework-ec/hx20/ec.bin"}"
    assume_yes=0
    image="$default_image"
    framework_tool="${frameworkTool}/bin/framework_tool"
    ectool="${framework-ec}/bin/framework_ectool"
    expected_dmi_board_name="''${FRAMEWORK_EC_FLASH_EXPECTED_DMI_BOARD_NAME:-FRANBMCP0A}"
    require_ac="''${FRAMEWORK_EC_FLASH_REQUIRE_AC:-1}"
    min_battery_capacity="''${FRAMEWORK_EC_FLASH_MIN_BATTERY_CAPACITY:-50}"
    power_refusal_exit_code="''${FRAMEWORK_EC_FLASH_POWER_REFUSAL_EXIT_CODE:-1}"

    status() {
      echo "framework-ec-flash: $*"
      if [ -n "''${NOTIFY_SOCKET:-}" ]; then
        systemd-notify --status="framework-ec-flash: $*" || true
      fi
    }

    refuse_power() {
      echo "framework-ec-flash: $*" >&2
      exit "$power_refusal_exit_code"
    }

    report_mismatch() {
      expected="$1"
      actual="$2"
      label="$3"

      echo "framework-ec-flash: verification failed: live $label contents differ after write" >&2
      echo "framework-ec-flash: expected sha256 $(sha256sum "$expected" | cut -d' ' -f1)" >&2
      echo "framework-ec-flash: actual   sha256 $(sha256sum "$actual" | cut -d' ' -f1)" >&2

      cmp_output="$workdir/cmp-$label.txt"
      cmp -l "$expected" "$actual" > "$cmp_output" 2>/dev/null || true
      diff_byte=
      if IFS=' ' read -r diff_byte _ < "$cmp_output" && [ -n "$diff_byte" ]; then
        diff_offset=$((diff_byte - 1))
        context_offset=$((diff_offset >= 16 ? diff_offset - 16 : 0))
        echo "framework-ec-flash: first differing $label byte offset: $diff_offset" >&2
        echo "framework-ec-flash: expected bytes around first difference:" >&2
        dd if="$expected" bs=1 skip="$context_offset" count=64 status=none | od -An -tx1 >&2
        echo "framework-ec-flash: actual bytes around first difference:" >&2
        dd if="$actual" bs=1 skip="$context_offset" count=64 status=none | od -An -tx1 >&2
      fi

      diagnostics_dir="''${FRAMEWORK_EC_FLASH_DIAGNOSTICS_DIR:-}"
      if [ -z "$diagnostics_dir" ]; then
        if [ "$(id -u)" -eq 0 ]; then
          diagnostics_dir=/var/lib/framework-ec-flash
        else
          diagnostics_dir="''${TMPDIR:-/tmp}/framework-ec-flash-diagnostics"
        fi
      fi
      mkdir -p "$diagnostics_dir"
      cp "$expected" "$diagnostics_dir/expected-$label.bin"
      cp "$actual" "$diagnostics_dir/actual-$label.bin"
      echo "framework-ec-flash: wrote diagnostic copies to $diagnostics_dir" >&2
    }

    check_dmi_board() {
      [ -n "$expected_dmi_board_name" ] || return 0

      actual_board_name="$(cat /sys/class/dmi/id/board_name 2>/dev/null || true)"
      if [ "$actual_board_name" != "$expected_dmi_board_name" ]; then
        echo "framework-ec-flash: refusing to flash Framework EC image: expected DMI board_name $expected_dmi_board_name, got ''${actual_board_name:-unknown}" >&2
        exit 1
      fi
    }

    region_sha256() {
      sha256sum "$1" | cut -d' ' -f1
    }

    first_difference_offset() {
      expected="$1"
      actual="$2"
      label="$3"
      cmp_output="$workdir/cmp-current-$label.txt"

      cmp -l "$expected" "$actual" > "$cmp_output" 2>/dev/null || true
      diff_byte=
      if IFS=' ' read -r diff_byte _ < "$cmp_output" && [ -n "$diff_byte" ]; then
        printf '%s\n' "$((diff_byte - 1))"
      else
        printf '%s\n' unknown
      fi
    }

    report_region_difference() {
      expected="$1"
      actual="$2"
      label="$3"

      if cmp -s "$expected" "$actual"; then
        status "$label region matches configured firmware"
        return 0
      fi

      first_diff="$(first_difference_offset "$expected" "$actual" "$label")"
      status "$label region differs from configured firmware"
      status "$label expected sha256 $(region_sha256 "$expected")"
      status "$label current  sha256 $(region_sha256 "$actual")"
      status "$label first differing byte offset $first_diff"
      return 1
    }

    wait_for_ec() {
      for _ in $(seq 1 30); do
        if ec_version="$("''${ectool_cmd[@]}" version 2>/dev/null)"; then
          return 0
        fi
        sleep 0.2
      done

      echo "framework-ec-flash: timed out waiting for Framework EC to answer version requests" >&2
      exit 1
    }

    get_ec_copy() {
      ec_copy=unknown
      while IFS= read -r line; do
        case "$line" in
          "Firmware copy:"*)
            ec_copy="''${line#Firmware copy:}"
            while [ "''${ec_copy# }" != "$ec_copy" ]; do
              ec_copy="''${ec_copy# }"
            done
            ;;
        esac
      done <<EOF
    $ec_version
    EOF
      printf '%s\n' "$ec_copy"
    }

    check_live_ec_target() {
      wait_for_ec
      case "$ec_version" in
        *hx20*) ;;
        *)
          echo "framework-ec-flash: refusing to flash Framework EC image: live EC version does not look like hx20" >&2
          echo "$ec_version" >&2
          exit 1
          ;;
      esac

      status "current EC firmware copy is $(get_ec_copy)"
    }

    check_ac_power() {
      [ "$require_ac" = "1" ] || return 0

      ac_online=0
      for online_path in /sys/class/power_supply/*/online; do
        [ -e "$online_path" ] || continue
        power_supply_dir="$(dirname "$online_path")"
        power_supply_type="$(cat "$power_supply_dir/type" 2>/dev/null || true)"
        if [ "$power_supply_type" = "Mains" ] && [ "$(cat "$online_path")" = "1" ]; then
          ac_online=1
        fi
      done

      if [ "$ac_online" != "1" ]; then
        refuse_power "refusing to flash Framework EC image without AC power"
      fi
    }

    check_battery_capacity() {
      [ -n "$min_battery_capacity" ] || return 0

      battery_seen=0
      for capacity_path in /sys/class/power_supply/*/capacity; do
        [ -e "$capacity_path" ] || continue
        power_supply_dir="$(dirname "$capacity_path")"
        power_supply_type="$(cat "$power_supply_dir/type" 2>/dev/null || true)"
        [ "$power_supply_type" = "Battery" ] || continue

        battery_seen=1
        battery_capacity="$(cat "$capacity_path" 2>/dev/null || true)"
        case "$battery_capacity" in
          ""|*[!0-9]*)
            refuse_power "refusing to flash Framework EC image: could not read battery percentage from $capacity_path"
            ;;
        esac

        if [ "$battery_capacity" -lt "$min_battery_capacity" ]; then
          refuse_power "refusing to flash Framework EC image: battery is below $min_battery_capacity% ($battery_capacity%)"
        fi
      done

      if [ "$battery_seen" != "1" ]; then
        refuse_power "refusing to flash Framework EC image: no battery capacity reading found"
      fi
    }

    check_flash_write_protection() {
      flash_protect="$("''${ectool_cmd[@]}" flashprotect)"
      flash_protect_flags=
      while IFS= read -r line; do
        case "$line" in
          "Flash protect flags:"*)
            flash_protect_flags="$line"
            break
            ;;
        esac
      done <<EOF
    $flash_protect
    EOF

      case "$flash_protect_flags" in
        *"Flash protect flags:"*" wp_gpio_asserted"*|*"Flash protect flags:"*" all_now"*|*"Flash protect flags:"*" rw_now"*|*"Flash protect flags:"*" STUCK"*|*"Flash protect flags:"*" INCONSISTENT"*)
          echo "framework-ec-flash: refusing to flash Framework EC image: EC write protection is active" >&2
          echo "$flash_protect" >&2
          exit 1
          ;;
      esac
    }

    usage() {
      cat <<'EOF'
    Usage: framework-ec-flash [--yes] [EC_IMAGE]

    Flash a Framework embedded-controller image using Framework's firmware utility.
    If EC_IMAGE is omitted, the image from this package's framework-ec input is used.

    This is intended for Framework Laptop 13 11th Gen / hx20 EC images.
    Framework documents hx20 as running from RO, so the checker and final
    readback verification compare only the RO firmware region. EC_RW and
    padding/gap bytes are intentionally ignored.
    Framework's firmware utility handles the MEC flash-notify sequence that is
    required before reading or writing the EC SPI flash.

    Options:
      -y, --yes       Skip the interactive confirmation prompt.
      -h, --help      Show this help.
    EOF
    }

    while [ "$#" -gt 0 ]; do
      case "$1" in
        -y|--yes)
          assume_yes=1
          ;;
        -h|--help)
          usage
          exit 0
          ;;
        -*)
          echo "framework-ec-flash: unknown option: $1" >&2
          usage >&2
          exit 1
          ;;
        *)
          if [ "$image" != "$default_image" ]; then
            echo "framework-ec-flash: only one EC_IMAGE may be provided" >&2
            usage >&2
            exit 1
          fi
          image="$1"
          ;;
      esac
      shift
    done

    framework_tool_cmd=("$framework_tool")
    ectool_cmd=("$ectool")
    if [ "$(id -u)" -ne 0 ]; then
      if [ "$assume_yes" -eq 1 ]; then
        echo "framework-ec-flash: --yes requires running as root" >&2
        exit 1
      fi
      framework_tool_cmd=(sudo "$framework_tool")
      ectool_cmd=(sudo "$ectool")
    fi

    if [ "$assume_yes" -ne 1 ]; then
      echo "About to flash Framework EC image:"
      echo "  $image"
      echo
      echo "Interrupting this write or using the wrong image can leave the laptop unable to power on."
      echo "Confirm the live EC target first with:"
      echo "  sudo framework_ectool version"
      echo
      printf 'Type FLASH to continue: '
      read -r confirmation

      if [ "$confirmation" != "FLASH" ]; then
        echo "Aborted."
        exit 1
      fi
    fi

    if [ ! -f "$image" ]; then
      echo "framework-ec-flash: image does not exist: $image" >&2
      exit 1
    fi

    status "checking DMI board"
    check_dmi_board

    status "checking live EC target"
    check_live_ec_target

    status "validating image"
    size=$(wc -c < "$image")
    if [ "$size" -ne 524288 ]; then
      echo "framework-ec-flash: expected a 524288-byte EC image, got $size bytes: $image" >&2
      exit 1
    fi

    status "preparing hx20 firmware regions"
    workdir="$(mktemp -d "''${TMPDIR:-/tmp}/framework-ec-flash.XXXXXX")"
    cleanup() {
      rc=$?
      rm -rf "$workdir"
      exit "$rc"
    }
    trap cleanup EXIT

    expected_ro="$workdir/expected-RO.bin"
    current_flash="$workdir/current-ec.bin"
    current_wp_ro="$workdir/current-WP_RO.bin"
    verified_flash="$workdir/verified-ec.bin"
    verified_ro="$workdir/verified-RO.bin"

    dd if="$image" of="$expected_ro" bs=1 count=$((0x3c000)) status=none

    status "dumping current EC flash"
    "''${framework_tool_cmd[@]}" --dump-ec-flash "$current_flash"
    dd if="$current_flash" of="$current_wp_ro" bs=1 count=$((0x3c000)) status=none

    if report_region_difference "$expected_ro" "$current_wp_ro" RO; then
      status "EC RO firmware is already flashed; ignoring EC_RW and padding/gap bytes"
      exit 0
    fi

    status "EC RO firmware differs from configured firmware"

    status "checking AC power"
    check_ac_power

    status "checking battery capacity"
    check_battery_capacity

    status "checking EC write protection"
    check_flash_write_protection

    status "flashing EC RO; wrapper will verify RO by final readback afterward"
    "''${framework_tool_cmd[@]}" --force --flash-ro-ec "$image"

    status "firmware utility finished; verifying EC flash by readback"
    "''${framework_tool_cmd[@]}" --dump-ec-flash "$verified_flash"
    dd if="$verified_flash" of="$verified_ro" bs=1 count=$((0x3c000)) status=none
    if ! cmp -s "$expected_ro" "$verified_ro"; then
      report_mismatch "$expected_ro" "$verified_ro" RO
      exit 1
    fi

    status "EC RO firmware flash complete"
  '';

  meta = {
    description = "Opt-in helper for flashing a Framework embedded-controller image";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "framework-ec-flash";
  };
}
