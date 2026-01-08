# Thunderbolt 4 DisplayPort Tunnel Failure After Hibernate Resume

## Summary

After resuming from hibernate, the Thunderbolt PCIe bridges (bus 80/81) fail to transition from D3cold to D0 power state. USB devices connected via Thunderbolt recover and enumerate successfully, but DisplayPort tunneling fails to re-establish. External monitors report "No Thunderbolt signal" despite the kernel and Wayland compositor showing them as connected and enabled.

## System Information

- **Hardware**: Framework Laptop 13 (11th Gen Intel), Board: FRANBMCP0A
- **CPU**: 11th Gen Intel Core i5-1135G7 @ 2.40GHz (Tiger Lake-LP)
- **BIOS Version**: 03.23
- **Kernel**: 6.18.3 (NixOS, PREEMPT_DYNAMIC)
- **Thunderbolt Controller**: Intel Tiger Lake-LP Thunderbolt 4 [8086:9a1b]
- **Thunderbolt Bridge**: Intel Goshen Ridge 2020 [8086:0b26] (rev 03)
- **Thunderbolt NVM Version**: 44.83
- **Connected Device**: Dell U3225QE monitor (vendor=0xd4, device=0xc052)

## PCI Topology

```
00:07.0 PCI bridge [0604]: Intel Corporation Tiger Lake-LP Thunderbolt 4 PCI Express Root Port #0 [8086:9a23] (rev 01)
00:07.1 PCI bridge [0604]: Intel Corporation Tiger Lake-LP Thunderbolt 4 PCI Express Root Port #1 [8086:9a25] (rev 01)
00:07.2 PCI bridge [0604]: Intel Corporation Tiger Lake-LP Thunderbolt 4 PCI Express Root Port #2 [8086:9a27] (rev 01)
00:07.3 PCI bridge [0604]: Intel Corporation Tiger Lake-LP Thunderbolt 4 PCI Express Root Port #3 [8086:9a29] (rev 01)
00:0d.0 USB controller [0c03]: Intel Corporation Tiger Lake-LP Thunderbolt 4 USB Controller [8086:9a13] (rev 01)
00:0d.2 USB controller [0c03]: Intel Corporation Tiger Lake-LP Thunderbolt 4 NHI #0 [8086:9a1b] (rev 01)
00:0d.3 USB controller [0c03]: Intel Corporation Tiger Lake-LP Thunderbolt 4 NHI #1 [8086:9a1d] (rev 01)
80:00.0 PCI bridge [0604]: Intel Corporation Thunderbolt 4 Bridge [Goshen Ridge 2020] [8086:0b26] (rev 03)
81:00.0 PCI bridge [0604]: Intel Corporation Thunderbolt 4 Bridge [Goshen Ridge 2020] [8086:0b26] (rev 03)
81:01.0 PCI bridge [0604]: Intel Corporation Thunderbolt 4 Bridge [Goshen Ridge 2020] [8086:0b26] (rev 03)
81:02.0 PCI bridge [0604]: Intel Corporation Thunderbolt 4 Bridge [Goshen Ridge 2020] [8086:0b26] (rev 03)
81:03.0 PCI bridge [0604]: Intel Corporation Thunderbolt 4 Bridge [Goshen Ridge 2020] [8086:0b26] (rev 03)
```

## Steps to Reproduce

1. Connect a Thunderbolt 4 display (Dell U3225QE) to the Framework laptop
2. Verify external display is working normally
3. Hibernate the system (`systemctl hibernate`)
4. Resume from hibernate
5. External display shows "No Thunderbolt signal" and enters standby

## Observed Behavior

### Kernel Log During Resume (journalctl -k)

```
Jan 08 10:08:19 framie kernel: thunderbolt 1-3: device disconnected
Jan 08 10:08:20 framie kernel: pci 0000:81:03.0: buffer not found in pci_save_pcie_state
Jan 08 10:08:24 framie kernel: pcieport 0000:80:00.0: Unable to change power state from D3cold to D0, device inaccessible
Jan 08 10:08:24 framie kernel: pci 0000:81:00.0: Unable to change power state from D0 to D0, device inaccessible
Jan 08 10:08:24 framie kernel: pci 0000:81:01.0: Unable to change power state from D0 to D0, device inaccessible
Jan 08 10:08:24 framie kernel: pci 0000:81:02.0: Unable to change power state from D0 to D0, device inaccessible
Jan 08 10:08:24 framie kernel: pci 0000:81:01.0: Unable to change power state from D3cold to D0, device inaccessible
Jan 08 10:08:24 framie kernel: pci 0000:81:03.0: buffer not found in pci_save_pcie_state
Jan 08 10:08:24 framie kernel: pci 0000:81:02.0: Unable to change power state from D3cold to D0, device inaccessible
```

### After Physical Cable Reconnection

Even after physically disconnecting and reconnecting the Thunderbolt cable:

```
Jan 08 10:27:19 framie kernel: pcieport 0000:80:00.0: Unable to change power state from D3cold to D0, device inaccessible
Jan 08 10:27:19 framie kernel: pci 0000:81:00.0: Unable to change power state from D3cold to D0, device inaccessible
Jan 08 10:27:19 framie kernel: pci 0000:81:01.0: Unable to change power state from D3cold to D0, device inaccessible
Jan 08 10:27:19 framie kernel: pci 0000:81:02.0: Unable to change power state from D3cold to D0, device inaccessible
Jan 08 10:27:19 framie kernel: pci 0000:81:03.0: buffer not found in pci_save_pcie_state
Jan 08 10:27:20 framie kernel: thunderbolt 1-3: new device found, vendor=0xd4 device=0xc052
Jan 08 10:27:20 framie kernel: thunderbolt 1-3: DELL U3225QE
Jan 08 10:27:20 framie kernel: thunderbolt 1-3: device disconnected
```

The device connects and immediately disconnects due to PCIe power state failures.

### State After Failed Resume

- `wlr-randr` shows the display as connected and enabled at 3840x2160@60Hz
- The physical monitor displays "No Thunderbolt (140) signal from your device"
- USB devices through the dock (ethernet, USB hubs) function normally
- No DP tunnel establishment messages appear in dmesg
- `cat /sys/bus/thunderbolt/devices/*/device_name` shows "U3225QE"
- The device is authorized (`authorized = 1`)

### Recovery Attempts That Failed

1. `modprobe -r thunderbolt && modprobe thunderbolt` - Module is in use
2. PCIe device remove/rescan - Hangs indefinitely or permission denied
3. xHCI controller unbind/bind - Only affects USB, not DisplayPort tunnels
4. Thunderbolt device de-authorize/re-authorize - "Operation not permitted" / "Invalid argument"
5. Physical cable disconnect/reconnect - PCIe bridges remain stuck in D3cold
6. `wlr-randr --output DP-6 --off && wlr-randr --output DP-6 --on` - No effect

### Only Working Recovery

Full system reboot.

## Root Cause Analysis

The Thunderbolt PCIe bridges (bus 80/81, Goshen Ridge) enter D3cold during hibernate. On resume, the PCIe subsystem attempts to restore power state but the devices are inaccessible - likely due to:

1. Platform Management Controller (PMC) not having properly restored power rails
2. Thunderbolt controller not responding to PCIe configuration space accesses
3. Missing coordination between thunderbolt driver resume and PCIe power management

The USB path recovers because xHCI uses a different code path, but the PCIe-based DisplayPort tunneling requires the Goshen Ridge bridges to be functional.

The `buffer not found in pci_save_pcie_state` message for 81:03.0 suggests the PCIe state wasn't properly saved before hibernate, compounding the resume failure.

## Workaround

Disabling Thunderbolt power saving prevents entry into D3cold:

```
options thunderbolt power_save=0
```

This trades idle power consumption for reliable hibernate resume.

## Potential Upstream Fixes

1. **thunderbolt driver**: Add retry logic when PCIe bridges fail to resume; force full re-enumeration if initial resume fails
2. **PCIe subsystem**: Better handling of devices that fail D3cold->D0 transition; don't assume device is accessible after power state change request
3. **Platform coordination**: Ensure PMC power sequencing completes before attempting PCIe restoration
4. **Hibernate path**: Save Thunderbolt tunnel state and explicitly re-establish after resume rather than assuming tunnels persist

## Related Issues

- Framework Community: Thunderbolt dock issues after sleep/hibernate are frequently reported
- Similar behavior reported on other Tiger Lake systems with Thunderbolt 4
- Dell Thunderbolt docks have known hibernate compatibility issues on Linux

## Relevant Kernel Code

- `drivers/thunderbolt/` - Thunderbolt/USB4 driver
- `drivers/pci/pcie/portdrv_pci.c` - PCIe port driver power management
- `drivers/pci/pci-driver.c` - `pci_pm_resume()` and D-state transitions

## Additional Data

Full kernel logs and system state available upon request.
