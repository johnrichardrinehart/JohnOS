# How to Report This Issue

## Primary Venues

### 1. Linux Kernel Bugzilla (Recommended)
- **URL**: https://bugzilla.kernel.org/enter_bug.cgi
- **Product**: Drivers
- **Component**: PCI
- **Summary**: "Thunderbolt 4 PCIe bridges fail D3cold->D0 transition after hibernate (Tiger Lake)"
- **Attach**: `report.md` contents

### 2. Linux USB Mailing List
- **Email**: linux-usb@vger.kernel.org
- **CC**: linux-pci@vger.kernel.org, thunderbolt-software@lists.linux.dev
- **Subject**: "[BUG] Thunderbolt 4 DisplayPort tunnels fail after hibernate - PCIe D3cold resume broken"
- **Note**: Plain text only, no HTML. Inline the report or attach as .txt

### 3. Framework Community Forum
- **URL**: https://community.frame.work/c/framework-laptop-13/linux/91
- **Tag**: linux, thunderbolt, hibernate
- **Note**: Framework engineers and kernel developers monitor this forum actively

### 4. Freedesktop GitLab (if display-related component)
- **URL**: https://gitlab.freedesktop.org/drm/intel/-/issues
- **Note**: More appropriate if the issue is determined to be in the i915/display driver

## Before Reporting

1. Check if already reported:
   - Search bugzilla.kernel.org for "thunderbolt hibernate D3cold"
   - Search Framework community for "thunderbolt hibernate"

2. Test with latest mainline kernel if possible (to see if already fixed)

3. Gather additional data if requested:
   ```bash
   # Full dmesg after failed resume
   dmesg > dmesg-after-hibernate.txt

   # PCIe device power states
   lspci -vvv > lspci-verbose.txt

   # Thunderbolt device info
   cat /sys/bus/thunderbolt/devices/*/uevent > thunderbolt-devices.txt

   # ACPI tables (may be requested)
   sudo acpidump > acpi-tables.dat
   ```

## Workaround Reference

If reporters ask for workarounds, point them to the modprobe option:

```
options thunderbolt power_save=0
```

Add to `/etc/modprobe.d/thunderbolt.conf` or equivalent for their distro.

## Related Upstream Discussions

- https://lore.kernel.org/linux-usb/ (search for thunderbolt hibernate)
- https://github.com/intel/thunderbolt-software-user-space/issues
