# Plan: Fast Nix I/O with SSD Overlay Store for Rock 5C

## Overview

Configure Rock 5C to use the 1TB SSD for faster Nix operations:
- Overlay store: Read-only base on eMMC, writable overlay on SSD
- Build operations on SSD
- Fetcher cache on SSD
- Graceful degradation: System boots and operates without SSD

## Current State

- **Root/Store**: `/dev/disk/by-label/NIXOS_SD` (eMMC, ext4) - slow flash
- **SSD** (`/dev/sdd`): 1TB in `nas` VG, ~3GB used as dm-cache (writeback mode)
- **NAS**: `/mnt/nas` (btrfs on HDD `/dev/sda` with SSD writeback cache)

## Implementation Stages

### Stage 1: NixOS Configuration Changes (Do Now)

Create a new branch and commit. These changes prepare the system to use the overlay store once the SSD LV is ready. The overlay store will gracefully fail if the SSD isn't ready yet (via `nofail` and `ConditionPathIsMountPoint`).

**Branch workflow:**
```bash
git stash  # if needed
git checkout -b feature/nix-overlay-store
# ... make changes ...
git add -A && git commit -m "rock5c: add SSD overlay store for Nix"
```

### Stage 2: LVM Reconfiguration (Do Later When NAS is Free)

Run these commands on the running machine once services are stopped and NAS is unmounted. No rescue boot required - just need the NAS to be idle.

**Commands to run (when NAS is free)**
```bash
# 1. Activate VG
vgchange -ay nas

# 2. Detach cache (preserves data, just removes caching)
lvconvert --uncache nas/storage

# 3. Check free PEs on SSD
pvs /dev/sdd

# 4. Create new 50GB cache data LV on SSD
lvcreate -L 50G -n cache_data nas /dev/sdd

# 5. Create cache metadata LV (rule of thumb: 1/1000 of data size, min 8MB)
lvcreate -L 512M -n cache_meta nas /dev/sdd

# 6. Combine into cache pool
lvconvert --type cache-pool \
  --poolmetadata nas/cache_meta \
  --cachemode writeback \
  nas/cache_data

# 7. Attach cache pool to storage
lvconvert --type cache \
  --cachepool nas/cache_data \
  nas/storage

# 8. Create 500GB LV for Nix on remaining SSD space
lvcreate -L 500G -n nix_ssd nas /dev/sdd

# 9. Format as btrfs with compression
mkfs.btrfs -L NIX_SSD /dev/nas/nix_ssd

# 10. Create subvolumes (after first mount)
mount /dev/nas/nix_ssd /mnt
btrfs subvolume create /mnt/@upper
btrfs subvolume create /mnt/@work
btrfs subvolume create /mnt/@build
btrfs subvolume create /mnt/@cache
umount /mnt
```

### Stage 1 Details: NixOS Configuration Changes

#### 1.1 Update `nixos-modules/rock5c/default.nix`

Add overlay store options under the rock5c module namespace:

```nix
# In options.dev.johnrinehart.rock5c, add:
overlayStore = {
  enable = lib.mkEnableOption "SSD-backed overlay store for Nix";

  device = lib.mkOption {
    type = lib.types.str;
    default = "/dev/disk/by-label/NIX_SSD";
    description = "Block device for the Nix SSD partition";
  };

  mountPoint = lib.mkOption {
    type = lib.types.path;
    default = "/mnt/nix-ssd";
    description = "Base mount point for SSD btrfs volume";
  };
};
```

#### 1.2 Add overlay store config block in `nixos-modules/rock5c/default.nix`

```nix
config = lib.mkIf cfg.enable {
  # ... existing rock5c config ...
} // lib.mkIf cfg.overlayStore.enable {

  # Mount btrfs SSD volume
  fileSystems.${cfg.overlayStore.mountPoint} = {
    device = cfg.overlayStore.device;
    fsType = "btrfs";
    options = [
      "subvol=/"
      "compress=zstd"
      "noatime"
      "nofail"
      "x-systemd.device-timeout=10s"
    ];
  };

  # Mount subvolumes
  fileSystems."${cfg.overlayStore.mountPoint}/upper" = {
    device = cfg.overlayStore.device;
    fsType = "btrfs";
    options = [ "subvol=@upper" "compress=zstd" "noatime" "nofail" ];
  };

  fileSystems."${cfg.overlayStore.mountPoint}/work" = {
    device = cfg.overlayStore.device;
    fsType = "btrfs";
    options = [ "subvol=@work" "compress=zstd" "noatime" "nofail" ];
  };

  fileSystems."${cfg.overlayStore.mountPoint}/build" = {
    device = cfg.overlayStore.device;
    fsType = "btrfs";
    options = [ "subvol=@build" "compress=zstd" "noatime" "nofail" ];
  };

  fileSystems."${cfg.overlayStore.mountPoint}/cache" = {
    device = cfg.overlayStore.device;
    fsType = "btrfs";
    options = [ "subvol=@cache" "compress=zstd" "noatime" "nofail" ];
  };

  # Overlay mount on /nix/store (post-boot, before nix-daemon)
  systemd.mounts = [{
    what = "overlay";
    where = "/nix/store";
    type = "overlay";
    mountConfig.Options = lib.concatStringsSep "," [
      "lowerdir=/nix/store"
      "upperdir=${cfg.overlayStore.mountPoint}/upper"
      "workdir=${cfg.overlayStore.mountPoint}/work"
    ];

    unitConfig = {
      ConditionPathIsMountPoint = cfg.overlayStore.mountPoint;
      DefaultDependencies = false;
    };

    after = [
      "local-fs.target"
      "${utils.escapeSystemdPath cfg.overlayStore.mountPoint}.mount"
      "${utils.escapeSystemdPath "${cfg.overlayStore.mountPoint}/upper"}.mount"
      "${utils.escapeSystemdPath "${cfg.overlayStore.mountPoint}/work"}.mount"
    ];
    requires = [
      "${utils.escapeSystemdPath cfg.overlayStore.mountPoint}.mount"
    ];
    before = [ "nix-daemon.service" "nix-daemon.socket" ];
    wantedBy = [ "multi-user.target" ];
  }];

  # Ensure nix-daemon waits for overlay
  systemd.services.nix-daemon = {
    after = [ "nix-store.mount" ];
    requires = lib.mkDefault []; # Don't hard-require, allow fallback
    wants = [ "nix-store.mount" ];
    environment.TMPDIR = "${cfg.overlayStore.mountPoint}/build";
  };

  systemd.sockets.nix-daemon = {
    after = [ "nix-store.mount" ];
    wants = [ "nix-store.mount" ];
  };

  # Nix settings
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
      "local-overlay-store"
    ];
    build-dir = "${cfg.overlayStore.mountPoint}/build";
  };

  # Build directory permissions
  systemd.tmpfiles.rules = [
    "d ${cfg.overlayStore.mountPoint}/build 1775 root nixbld -"
  ];

  # Bind mount for user cache (graceful fallback via nofail)
  fileSystems."/home/john/.cache/nix" = {
    device = "${cfg.overlayStore.mountPoint}/cache";
    fsType = "none";
    options = [ "bind" "nofail" "x-systemd.requires=${utils.escapeSystemdPath cfg.overlayStore.mountPoint}.mount" ];
  };
};
```

#### 1.3 Update `nixos-configurations/rock5c_minimal/default.nix`

```nix
dev.johnrinehart.rock5c.overlayStore.enable = true;
```

## Critical Files to Modify

| File | Change |
|------|--------|
| `nixos-modules/rock5c/default.nix` | Add `overlayStore` options and config |
| `nixos-configurations/rock5c_minimal/default.nix` | Enable `overlayStore` |

## Key Technical Notes

1. **Post-boot overlay (not initrd)**: Since `.toplevel` is on eMMC, the system boots without SSD. The overlay is mounted via systemd before `nix-daemon` starts. This is simpler than initrd modifications.

2. **btrfs with compression**: Using `compress=zstd` for better space efficiency. Subvolumes allow flexible management.

3. **Graceful fallback**:
   - `nofail` on all SSD mounts
   - `ConditionPathIsMountPoint` on overlay mount
   - `wants` (not `requires`) for nix-daemon dependency
   - If SSD absent, system boots with eMMC store only

4. **NIX_CACHE_HOME behavior**: Nix checks `NIX_CACHE_HOME` → `XDG_CACHE_HOME/nix` → `~/.cache/nix`. It does NOT auto-create directories. Using bind mount with `nofail` is safer - if SSD missing, bind fails and `~/.cache/nix` is used normally.

5. **dm-cache preserved**: Writeback mode maintained. Only the cache pool is resized, not replaced.

6. **LVM constraint**: dm-cache operations require the cached LV to be inactive. Rescue mode or careful service shutdown needed.

## Verification Steps

### After LVM Reconfiguration

```bash
# Verify cache is reattached with writeback mode
lvs -o+cache_mode nas/storage

# Verify Nix LV exists
blkid /dev/nas/nix_ssd

# Check btrfs subvolumes
mount /dev/nas/nix_ssd /mnt && btrfs subvolume list /mnt
```

### After NixOS Rebuild

```bash
# Check mounts
findmnt /mnt/nix-ssd
findmnt /nix/store

# Verify overlay
mount | grep overlay
cat /proc/mounts | grep "nix/store"

# Test build
time nix build nixpkgs#hello --rebuild

# Check cache location
ls -la ~/.cache/nix/
findmnt ~/.cache/nix
```

### Verify Graceful Degradation

```bash
# Simulate SSD absence (careful!)
# System should boot with eMMC /nix/store, no overlay
systemctl status nix-store.mount  # Should show failed/inactive if no SSD
nix --version  # Should still work
```

## Rollback

1. **NixOS rollback**: Select previous generation from extlinux boot menu
2. **Disable overlay**: Set `dev.johnrinehart.rock5c.overlayStore.enable = false`
3. **LVM restore**: Can extend cache back to full SSD if needed

## Alternative: Simpler Build-Only Approach

If full overlay is problematic, use SSD just for builds:

```nix
# Only SSD for builds, no store overlay
fileSystems."/mnt/nix-ssd" = {
  device = "/dev/disk/by-label/NIX_SSD";
  fsType = "btrfs";
  options = [ "compress=zstd" "noatime" "nofail" ];
};

systemd.services.nix-daemon.environment.TMPDIR = "/mnt/nix-ssd/build";
nix.settings.build-dir = "/mnt/nix-ssd/build";
```

## Sources

- [Nix Local Overlay Store Manual](https://nix.dev/manual/nix/2.32/store/types/experimental-local-overlay-store)
- [Nix users.cc source](https://github.com/NixOS/nix/blob/master/src/libutil/users.cc) - NIX_CACHE_HOME fallback behavior
- [lvmcache man page](https://www.man7.org/linux/man-pages/man7/lvmcache.7.html)
- [OverlayFS kernel docs](https://docs.kernel.org/filesystems/overlayfs.html)
