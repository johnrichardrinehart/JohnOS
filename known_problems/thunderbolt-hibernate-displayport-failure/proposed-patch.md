# Proposed Kernel Patches for Thunderbolt Hibernate Resume Failure

## Patch Files

| Option | File | Subsystem | Description |
|--------|------|-----------|-------------|
| 1 | `0001-PCI-Add-retry-logic-for-D3cold-resume.patch` | PCI | Add retry logic in pci_power_up() (Recommended) |
| 2 | `0002-thunderbolt-disable-D3cold-during-hibernate.patch` | Thunderbolt | Disable D3cold during hibernate (Workaround) |
| 3 | `0003-thunderbolt-harmonize-freeze-with-suspend.patch` | Thunderbolt | Make freeze_noirq match suspend_noirq |

## Analysis Summary

After hibernate resume, the Thunderbolt PCIe bridges (Intel Goshen Ridge) fail to transition from D3cold to D0. The `pci_power_up()` function in `drivers/pci/pci.c` calls `platform_pci_set_power_state(dev, PCI_D0)` via ACPI, then immediately tries to read the PM_CTRL register. If the device isn't accessible yet (returns 0xFFFF), it gives up with `-EIO`.

The problem is:
1. ACPI powers on the device
2. The Thunderbolt controller needs time to initialize
3. The kernel doesn't wait - it immediately reads config space and fails
4. All downstream devices (including DisplayPort tunnels) become inaccessible

## Proposed Fix Option 1: Add retry logic in pci_power_up()

This is the most targeted fix - add a retry loop with delay for devices transitioning from D3cold.

```c
diff --git a/drivers/pci/pci.c b/drivers/pci/pci.c
index XXXXXXX..XXXXXXX 100644
--- a/drivers/pci/pci.c
+++ b/drivers/pci/pci.c
@@ -1303,6 +1303,8 @@ int pci_power_up(struct pci_dev *dev)
 {
 	bool need_restore;
 	pci_power_t state;
+	pci_power_t prev_state = dev->current_state;
+	int retries;
 	u16 pmcsr;

 	platform_pci_set_power_state(dev, PCI_D0);
@@ -1321,9 +1323,26 @@ int pci_power_up(struct pci_dev *dev)
 		return -EIO;
 	}

-	pci_read_config_word(dev, dev->pm_cap + PCI_PM_CTRL, &pmcsr);
-	if (PCI_POSSIBLE_ERROR(pmcsr)) {
-		pci_err(dev, "Unable to change power state from %s to D0, device inaccessible\n",
+	/*
+	 * Devices resuming from D3cold may need additional time to become
+	 * accessible after platform power-on. This is particularly common
+	 * with Thunderbolt controllers after hibernate resume. Retry a few
+	 * times with increasing delays before giving up.
+	 */
+	for (retries = 0; retries < 5; retries++) {
+		if (retries > 0) {
+			unsigned int delay = 10 << retries; /* 20, 40, 80, 160 ms */
+			pci_info(dev, "D3cold resume: device not accessible, retrying in %u ms\n", delay);
+			msleep(delay);
+		}
+		pci_read_config_word(dev, dev->pm_cap + PCI_PM_CTRL, &pmcsr);
+		if (!PCI_POSSIBLE_ERROR(pmcsr))
+			break;
+	}
+
+	if (PCI_POSSIBLE_ERROR(pmcsr)) {
+		pci_err(dev, "Unable to change power state from %s to D0, device inaccessible after retries\n",
 			pci_power_name(dev->current_state));
 		dev->current_state = PCI_D3cold;
 		return -EIO;
```

**Pros:**
- Fixes the issue for all PCIe devices that have D3cold resume timing issues
- Minimal code change
- No regression risk for devices that work correctly (they pass first try)

**Cons:**
- Adds latency to resume path for broken devices
- May mask underlying firmware/ACPI bugs

## Proposed Fix Option 2: Thunderbolt-specific D3cold prevention

Prevent Thunderbolt bridges from entering D3cold during hibernate by marking them appropriately.

```c
diff --git a/drivers/thunderbolt/nhi.c b/drivers/thunderbolt/nhi.c
index XXXXXXX..XXXXXXX 100644
--- a/drivers/thunderbolt/nhi.c
+++ b/drivers/thunderbolt/nhi.c
@@ -1029,11 +1029,21 @@ static int nhi_poweroff_noirq(struct device *dev)
 {
 	struct pci_dev *pdev = to_pci_dev(dev);
 	bool wakeup;
+	int ret;

 	wakeup = device_may_wakeup(dev) && nhi_wake_supported(pdev);
-	return __nhi_suspend_noirq(dev, wakeup);
+	ret = __nhi_suspend_noirq(dev, wakeup);
+
+	/*
+	 * Prevent the device from entering D3cold during hibernation poweroff.
+	 * Some platforms have issues resuming Thunderbolt controllers from
+	 * D3cold, causing DisplayPort tunnel failures after hibernate resume.
+	 */
+	if (!ret)
+		pci_d3cold_disable(pdev);
+
+	return ret;
 }
```

But we'd also need to re-enable it on resume:

```c
diff --git a/drivers/thunderbolt/nhi.c b/drivers/thunderbolt/nhi.c
--- a/drivers/thunderbolt/nhi.c
+++ b/drivers/thunderbolt/nhi.c
@@ -1054,6 +1054,9 @@ static int nhi_resume_noirq(struct device *dev)
 	struct tb_nhi *nhi = tb->nhi;
 	int ret;

+	/* Re-enable D3cold that was disabled during poweroff */
+	pci_d3cold_enable(pdev);
+
 	/*
 	 * Check that the device is still there. It may be that the user
 	 * unplugged last device which causes the host controller to go
```

**Pros:**
- Targeted to Thunderbolt only
- No performance impact on other devices
- Keeps Thunderbolt in a more recoverable state

**Cons:**
- Higher hibernate power consumption (device stays in D3hot instead of D3cold)
- Doesn't fix the root cause in PCIe subsystem

## Proposed Fix Option 3: Harmonize freeze/thaw with suspend/resume in Thunderbolt driver

The `tb_freeze_noirq()` function doesn't properly prepare hardware for power loss like `tb_suspend_noirq()` does:

```c
diff --git a/drivers/thunderbolt/tb.c b/drivers/thunderbolt/tb.c
index XXXXXXX..XXXXXXX 100644
--- a/drivers/thunderbolt/tb.c
+++ b/drivers/thunderbolt/tb.c
@@ -3194,9 +3194,18 @@ static int tb_free_unplugged_xdomains(struct tb_switch *sw)

 static int tb_freeze_noirq(struct tb *tb)
 {
 	struct tb_cm *tcm = tb_priv(tb);

+	tb_dbg(tb, "freezing...\n");
+
+	/*
+	 * Prepare hardware for potential power loss during hibernation.
+	 * This mirrors tb_suspend_noirq() to ensure consistent state.
+	 */
+	tb_disconnect_and_release_dp(tb);
+	tb_switch_exit_redrive(tb->root_switch);
+	tb_switch_suspend(tb->root_switch, false);
 	tcm->hotplug_active = false;
+
+	tb_dbg(tb, "freeze finished\n");
 	return 0;
 }
```

**Pros:**
- Makes freeze/thaw consistent with suspend/resume
- Properly prepares DisplayPort tunnels for power loss
- Follows existing code patterns

**Cons:**
- May not fix the PCIe D3cold resume issue
- Only helps if the issue is tunnel state corruption, not PCIe access failure

## Recommended Approach

I recommend **Option 1** (retry logic in `pci_power_up()`) as the primary fix because:

1. It addresses the root cause - device not being accessible immediately after ACPI power-on
2. It's a defensive fix that helps any device with D3cold resume timing issues
3. The retry delays (20, 40, 80, 160 ms) are reasonable and only incurred when there's a problem

**Option 3** should also be considered as a complementary fix to ensure Thunderbolt tunnel state is properly managed during hibernation.

## Testing Notes

To test these patches:

1. Apply the patch
2. Build and install the kernel
3. Connect Thunderbolt display
4. Hibernate: `systemctl hibernate`
5. Resume and verify:
   - `journalctl -k` shows no "device inaccessible" errors
   - `wlr-randr` shows display connected
   - Physical display shows video output

## Mailing List Submission

When submitting to linux-pci@vger.kernel.org or linux-usb@vger.kernel.org:

```
Subject: [PATCH] PCI: Add retry logic for D3cold to D0 power state transitions

Some devices, particularly Thunderbolt controllers, need additional time
to become accessible after ACPI powers them on from D3cold. Currently
pci_power_up() reads the PM_CTRL register immediately after requesting
power-on and fails if the device isn't ready.

This is observed on Intel Tiger Lake systems with Thunderbolt 4 after
hibernate resume. The Goshen Ridge bridges return 0xFFFF when read too
early, causing "Unable to change power state from D3cold to D0, device
inaccessible" errors. This prevents DisplayPort tunneling from being
re-established.

Add a retry loop with exponential backoff (20-160ms) for devices resuming
from D3cold, giving them time to initialize before giving up.

Signed-off-by: [Your Name] <[your@email]>
---
```

## References

- Kernel source: `drivers/pci/pci.c` - `pci_power_up()`
- Kernel source: `drivers/thunderbolt/nhi.c` - PM callbacks
- Kernel source: `drivers/thunderbolt/tb.c` - Connection manager PM
- PCI Power Management Spec 1.2 - D-state transition timing
