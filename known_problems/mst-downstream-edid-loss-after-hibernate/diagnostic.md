# MST Downstream Monitor Missing EDID After Hibernate Resume

## Summary

After hibernate resume on a Framework 13 (11th Gen Intel, Tiger Lake-LP) with Thunderbolt-connected daisy-chained Dell monitors, the DP MST downstream monitor (Dell U2520D, 25") connects with missing EDID identity data. It appears as "Unknown Unknown Unknown" in niri while retaining valid mode timings. The upstream MST device (Dell U3225QE, 32") is always correctly identified.

This is a **partial EDID failure**: the MST topology re-enumerates, mode timings are available, but the EDID manufacturer/model/serial descriptors are lost or unreadable for the downstream device.

## System Information

- **Hardware**: Framework Laptop 13 (11th Gen Intel), Board: FRANBMCP0A
- **CPU**: 11th Gen Intel Core i5-1135G7 @ 2.40GHz (Tiger Lake-LP)
- **Kernel**: 6.18.3 (NixOS, PREEMPT_DYNAMIC)
- **Thunderbolt Controller**: Intel Tiger Lake-LP Thunderbolt 4 [8086:9a1b]
- **Thunderbolt Bridge**: Intel Goshen Ridge 2020 [8086:0b26] (rev 03)
- **Compositor**: niri
- **Upstream Monitor**: Dell U3225QE (32", 3840x2160) — Thunderbolt native, DP-6
- **Downstream Monitor**: Dell U2520D (25", 2560x1440) — MST via daisy-chain, DP-9

## Monitor Topology

```
Framework Laptop (TB4 port)
  └── Dell U3225QE (DP-6, Thunderbolt native connection)
        └── Dell U2520D (DP-9, MST downstream via DP daisy-chain)
```

## Observed Behavior

After hibernate resume, `niri msg outputs` shows:

```
Output "Dell Inc. DELL U3225QE 6WS9B84" (DP-6)    <-- correct
  Current mode: 3840x2160 @ 59.997 Hz (preferred)

Output "Unknown Unknown Unknown" (DP-9)             <-- EDID identity lost
  Current mode: 2560x1440 @ 59.951 Hz (preferred)
  Physical size: 550x310 mm                          <-- physical size IS present
  Available modes: [full list present]               <-- modes ARE present
```

Key observations:
- MST topology IS enumerated (downstream device visible as DP-9)
- Mode timings ARE present and correct
- Physical size IS present (550x310 mm matches U2520D spec)
- Make/model/serial are ALL "Unknown"
- This suggests EDID descriptor blocks (especially manufacturer/model strings in Display Descriptors) are unreadable, while timing data (from Standard/Detailed Timing blocks or DisplayID) succeeds

## Impact

niri's output matching (`niri-config/src/output.rs:190-201`) uses make+model+serial. When all are None/Unknown, the output gets auto-placed at a default position instead of the configured position, breaking multi-monitor cursor adjacency.

## Current Mitigations

### 1. Kernel patch: `i915-mst-resume-tc-hotplug.patch`

Applied to `drivers/gpu/drm/i915/display/intel_dp.c` in `intel_dp_mst_resume()`. When MST resume fails on a TC (Thunderbolt) port, it sets `display->hotplug.event_bits` for the encoder's HPD pin to schedule deferred re-detection.

**Analysis of patch effectiveness for this symptom:**

- The patch addresses **total MST failure** (DPCD read fails, topology torn down entirely)
- The user's symptom is **partial EDID failure** (MST works, modes present, identity lost)
- These may be the same root cause at different severity levels, or distinct issues
- The patch does NOT call `queue_delayed_detection_work()` — the `event_bits` wait for the next `hotplug_work` trigger (e.g., a real HPD interrupt from TB tunnel establishment)
- If MST partially succeeds (topology up, but EDID read incomplete), the patch may not trigger at all because `drm_dp_mst_topology_mgr_resume()` might return success

### 2. Compositor service: `niri-output-fixup`

NixOS systemd user service that detects "Unknown" outputs, matches by resolution, and repositions them to configured positions. Safety net while the kernel issue is unresolved.

## Diagnostic Procedure

### Step 1: Capture baseline (fresh boot, no hibernate)

```bash
# Full output state
niri msg outputs > /tmp/niri-outputs-fresh.txt
niri msg --json outputs > /tmp/niri-outputs-fresh.json

# Kernel display state
sudo cat /sys/kernel/debug/dri/0/i915_display_info > /tmp/display-info-fresh.txt

# MST topology
sudo cat /sys/kernel/debug/dri/0/i915_dp_mst_info > /tmp/mst-info-fresh.txt 2>/dev/null || true

# EDID for each connector
for conn in /sys/class/drm/card*-DP-*/edid; do
  echo "=== $conn ===" >> /tmp/edid-fresh.txt
  xxd "$conn" >> /tmp/edid-fresh.txt 2>/dev/null
done

# Thunderbolt device state
cat /sys/bus/thunderbolt/devices/*/device_name 2>/dev/null > /tmp/tb-devices-fresh.txt

# Kernel ring buffer
dmesg > /tmp/dmesg-fresh.txt
```

### Step 2: Hibernate and resume

```bash
systemctl hibernate
# Resume by pressing power button
```

### Step 3: Capture post-resume state (immediately after login)

```bash
# Same commands as Step 1 but with -resume suffix
niri msg outputs > /tmp/niri-outputs-resume.txt
niri msg --json outputs > /tmp/niri-outputs-resume.json

sudo cat /sys/kernel/debug/dri/0/i915_display_info > /tmp/display-info-resume.txt
sudo cat /sys/kernel/debug/dri/0/i915_dp_mst_info > /tmp/mst-info-resume.txt 2>/dev/null || true

for conn in /sys/class/drm/card*-DP-*/edid; do
  echo "=== $conn ===" >> /tmp/edid-resume.txt
  xxd "$conn" >> /tmp/edid-resume.txt 2>/dev/null
done

dmesg > /tmp/dmesg-resume.txt
```

### Step 4: Compare EDID data

```bash
diff /tmp/edid-fresh.txt /tmp/edid-resume.txt
```

If the downstream connector's EDID is entirely zeroed or missing post-resume, the issue is that the MST sideband EDID read failed. If partial, specific descriptor blocks failed.

### Step 5: Check kernel logs for MST/EDID errors

```bash
# MST resume messages
grep -i "mst.*resume\|mst.*fail\|mst.*tc\|deferred detection" /tmp/dmesg-resume.txt

# EDID read errors
grep -i "edid\|drm_do_get_edid\|drm_edid" /tmp/dmesg-resume.txt

# Hotplug events after resume
grep -i "hotplug\|hpd\|event_bits" /tmp/dmesg-resume.txt

# i915 display connector detection
grep -i "intel_dp_detect\|intel_dp_mst\|connector.*status" /tmp/dmesg-resume.txt
```

### Step 6: Enable verbose kernel debug logging (if needed)

```bash
# Enable DRM debug messages for KMS
echo 0x1e | sudo tee /sys/module/drm/parameters/debug

# Or for specific i915 debug:
echo 1 | sudo tee /sys/module/i915/parameters/enable_dp_mst

# Then hibernate/resume and capture dmesg again
```

### Step 7: Check if EDID recovers with manual re-detect

```bash
# Force connector re-detection
echo detect | sudo tee /sys/class/drm/card0-DP-9/status

# Then re-check
niri msg outputs
```

If manual re-detect recovers EDID, the issue is purely a timing/ordering problem during resume.

## Possible Root Causes (Ordered by Likelihood)

### 1. MST sideband EDID read timing (MOST LIKELY)

During resume, the MST topology manager re-reads EDID for each downstream device via sideband messages. The downstream device (U2520D) is behind an additional MST hop, so sideband messaging requires the full path to be stable. If the upstream device (U3225QE) hasn't fully initialized its MST branch device when EDID is read, the sideband transaction may time out or return partial data.

**Where to look**: `drm_dp_mst_get_edid()` → `drm_dp_send_get_edid_block()` in `drivers/gpu/drm/display/drm_dp_mst_topology.c`

### 2. DPCD link training incomplete for MST downstream

The DP link between the U3225QE and U2520D might not be trained yet when the kernel reads EDID. The link from laptop→U3225QE comes up first (TB tunnel), but the U3225QE→U2520D link (native DP MST) has its own link training.

**Where to look**: `drm_dp_mst_topology_mgr_resume()` in `drivers/gpu/drm/display/drm_dp_mst_topology.c`

### 3. Kernel patch ineffective for this case

`intel_dp_mst_resume()` may actually succeed (return 0) because the upstream MST device responds to DPCD — it's only the downstream sideband read that fails. In that case, our patch's deferred detection never triggers.

**How to verify**: Add `drm_dbg_kms` logging to `intel_dp_mst_resume()` to print the return value.

### 4. DRM EDID read retry insufficient

`drm_do_get_edid()` has retry logic (typically 4 attempts) but the timeout for MST sideband transactions may be too short for the downstream path during resume.

**Where to look**: `drm_do_get_edid()` in `drivers/gpu/drm/drm_edid.c`, `drm_dp_mst_aux_for_parent()` for aux channel routing

## Kernel Code Paths to Audit

| File | Function | Relevance |
|------|----------|-----------|
| `drivers/gpu/drm/i915/display/intel_dp.c` | `intel_dp_mst_resume()` | Our patch location; where MST resume starts |
| `drivers/gpu/drm/display/drm_dp_mst_topology.c` | `drm_dp_mst_topology_mgr_resume()` | MST topology re-establishment |
| `drivers/gpu/drm/display/drm_dp_mst_topology.c` | `drm_dp_send_get_edid_block()` | MST sideband EDID read |
| `drivers/gpu/drm/display/drm_dp_mst_topology.c` | `drm_dp_mst_get_edid()` | Entry point for MST EDID |
| `drivers/gpu/drm/drm_edid.c` | `drm_do_get_edid()` | Generic EDID read with retries |
| `drivers/gpu/drm/i915/display/intel_dp_mst.c` | `intel_dp_mst_get_edid()` | i915-specific MST EDID wrapper |
| `drivers/gpu/drm/i915/display/intel_ddi.c` | `intel_ddi_hotplug()` | Hotplug handler with TC retry logic |
| `drivers/gpu/drm/i915/display/intel_hotplug.c` | `i915_hotplug_work_func()` | Processes `event_bits` for deferred detection |

## Next Steps

1. **Run diagnostic steps 1-5 above** to capture actual EDID data pre/post hibernate
2. **Check if the patch's code path even triggers** by grepping for "scheduling deferred detection" in dmesg after resume
3. If patch doesn't trigger: the MST resume "succeeds" but downstream EDID is bad — patch is wrong fix
4. If EDID is entirely empty post-resume for DP-9: MST sideband EDID read failed
5. If EDID is partial: specific descriptor block read timed out
6. Consider adding a delayed EDID re-read for MST downstream devices after resume as a more targeted kernel fix

## Related Issues

- `known_problems/thunderbolt-hibernate-displayport-failure/` — TB PCIe D3cold issue (total display failure, different from this partial EDID loss)
- niri config matching: `niri-config/src/output.rs:190-201` — requires make/model/serial, fails when all Unknown
- niri-output-fixup service: compositor-level workaround matching by resolution
