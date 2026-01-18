# Rock 5C Linux 6.18.5 Testing Guide

**Kernel Version:** 6.18.5
**Branch:** rock-5c-hardware-support
**Hardware:** Radxa Rock 5C (RK3588s)
**Date:** 2026-01-15

---

## Part 1: Storage Setup - LVM Reconfiguration (Run First)

**IMPORTANT:** Run these commands ONLY when NAS services are stopped and the NAS volume is unmounted. No rescue boot required - just need the NAS to be idle.

### Prerequisites

```bash
# 1. Stop services using NAS
systemctl stop your-nas-services  # Adjust to your actual services

# 2. Unmount NAS
umount /mnt/nas

# 3. Verify nothing is using the volume
lsof | grep nas
fuser -m /dev/nas/storage  # Should be empty
```

### LVM Reconfiguration Steps

These commands will:
- Detach existing dm-cache (preserves data)
- Create 50GB cache + 512MB metadata
- Reattach cache in writeback mode
- Create 500GB LV for Nix overlay store on SSD
- Format as btrfs with compression

```bash
# 1. Activate volume group
vgchange -ay nas

# 2. Detach cache (preserves data, just removes caching)
lvconvert --uncache nas/storage

# 3. Check free space on SSD
pvs /dev/sdd
# Should show ~931GB free after uncaching (1TB = 931GiB in binary)

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

# 10. Create btrfs subvolumes
mount /dev/nas/nix_ssd /mnt
btrfs subvolume create /mnt/@upper
btrfs subvolume create /mnt/@work
btrfs subvolume create /mnt/@build
btrfs subvolume create /mnt/@cache
umount /mnt
```

### Verification

```bash
# Verify cache is reattached with writeback mode
lvs -o+cache_mode nas/storage
# Should show: cache_mode=writeback, cache_pool=cache_data

# Verify Nix LV exists
blkid /dev/nas/nix_ssd
# Should show: TYPE="btrfs" LABEL="NIX_SSD"

# Check btrfs subvolumes
mount /dev/nas/nix_ssd /mnt && btrfs subvolume list /mnt
# Should show: @upper, @work, @build, @cache

umount /mnt

# Remount NAS and restart services
mount /mnt/nas
systemctl start your-nas-services
```

### NixOS Configuration Changes

After LVM setup, NixOS rebuild will activate overlay store:

```bash
# Rebuild to activate overlay store configuration
sudo nixos-rebuild switch

# Verify overlay store mounts
findmnt /mnt/nix-ssd
findmnt /nix/store

# Check overlay configuration
mount | grep overlay
cat /proc/mounts | grep "nix/store"

# Verify nix-daemon is using SSD for builds
systemctl status nix-daemon.service
# Should show TMPDIR=/mnt/nix-ssd/build

# Test Nix build on SSD
time nix build nixpkgs#hello --rebuild
# Should be significantly faster than eMMC builds

# Check cache location
ls -la ~/.cache/nix/
findmnt ~/.cache/nix
# Should be bind-mounted to /mnt/nix-ssd/cache
```

---

## Part 2: Kernel Driver Verification

After booting into the new kernel, verify all Rockchip drivers loaded correctly.

### 2.1 Kernel Version Check

```bash
# Verify kernel version
uname -r
# Expected: 6.18.5

# Check kernel command line
cat /proc/cmdline

# Verify device tree
cat /proc/device-tree/model
# Expected: "Radxa ROCK 5C" or similar
```

### 2.2 MPP Video Codec Framework

```bash
# Check MPP service device
ls -l /dev/mpp_service
# Expected: crw-rw-rw- 1 root video

# Check MPP driver loaded
lsmod | grep rk_vcodec
# Expected: rk_vcodec module listed with dependencies

# Check decoder cores
ls -l /dev/rkvdec
# Expected: rkvdec0, rkvdec1 devices (2 cores)

# Check encoder cores
ls -l /dev/rkvenc
# Expected: rkvenc0, rkvenc1 devices (2 cores)

# Check MPP procfs entries (detailed status)
cat /proc/mpp_service/rkvdec
cat /proc/mpp_service/rkvenc
cat /proc/mpp_service/av1d
cat /proc/mpp_service/vdpu
cat /proc/mpp_service/vepu

# Check IOMMU domains
dmesg | grep -i "rkvdec.*iommu"
dmesg | grep -i "rkvenc.*iommu"
# Should show IOMMU attachment for each codec core
```

### 2.3 RGA3 2D Graphics Accelerator

```bash
# Check RGA3 device
ls -l /dev/rga
# Expected: crw-rw-rw- 1 root video

# Check RGA3 driver loaded
lsmod | grep rga3
# Expected: rga3 module listed

# Check RGA3 cores
dmesg | grep -i rga
# Should show 3 RGA cores initialized (rga3_core0, rga3_core1, rga3_core2)

# Check RGA3 procfs (if available)
cat /proc/rga/driver || echo "RGA proc not available (normal)"

# Check RGA3 IOMMU
dmesg | grep -i "rga.*iommu"
# Should show IOMMU attachment for RGA cores
```

### 2.4 NPU (Neural Processing Unit)

The kernel includes both mainline Rocket and vendor RKNPU drivers.

```bash
# Check NPU devices
ls -l /dev/accel/accel*
# Rocket mainline driver (DRM accelerator)

ls -l /dev/rknpu
# Vendor RKNPU driver (if enabled)

# Check loaded drivers
lsmod | grep rocket
lsmod | grep rknpu

# Check NPU in dmesg
dmesg | grep -i npu
dmesg | grep -i rocket

# Check NPU IOMMU
dmesg | grep -i "npu.*iommu"
```

### 2.5 DMC (Dynamic Memory Controller) - Memory Frequency Scaling

```bash
# Check DMC devfreq driver
ls -l /sys/class/devfreq/
# Should show dmc device

# Check current memory frequency
cat /sys/class/devfreq/dmc/cur_freq
cat /sys/class/devfreq/dmc/available_frequencies

# Check DMC governor
cat /sys/class/devfreq/dmc/governor
cat /sys/class/devfreq/dmc/available_governors

# Check DMC driver loaded
lsmod | grep rockchip_dmc
dmesg | grep -i dmc

# Monitor memory frequency changes
watch -n 1 cat /sys/class/devfreq/dmc/cur_freq
```

### 2.6 Rockchip Power Management

```bash
# Check SIP (Secure firmware interface)
lsmod | grep rockchip_sip
dmesg | grep -i sip

# Check OPP (Operating Performance Points)
lsmod | grep rockchip_opp
ls -l /sys/devices/system/cpu/cpu*/cpufreq/scaling_available_frequencies

# Check System Monitor
lsmod | grep rockchip_system_monitor
dmesg | grep -i "system.*monitor"

# Check IPA (Intelligent Power Allocation)
lsmod | grep rockchip_ipa
ls -l /sys/class/thermal/thermal_zone*/

# Check thermal zones
cat /sys/class/thermal/thermal_zone*/type
cat /sys/class/thermal/thermal_zone*/temp

# Check cooling devices
ls -l /sys/class/thermal/cooling_device*/
cat /sys/class/thermal/cooling_device*/type
```

### 2.7 Clocks and Power Domains

```bash
# Check clock framework
dmesg | grep -i "clk.*rockchip"
dmesg | grep -i "rk3588.*clk"

# Check power domains
dmesg | grep -i "power.*domain"
cat /sys/kernel/debug/pm_genpd/pm_genpd_summary  # (requires debugfs)
```

### 2.8 Module Dependency Check

```bash
# Verify all Rockchip modules loaded with correct dependencies
lsmod | grep -E "(rk_vcodec|rga3|rknpu|rockchip)"

# Check for missing symbols or dependency errors
dmesg | grep -i "unknown symbol"
dmesg | grep -i "unresolved"

# Should be empty - all symbols should resolve correctly
```

---

## Part 3: Hardware-Accelerated Video Codec Testing

This section tests H.264, H.265/HEVC, VP9, and AV1 hardware acceleration using FFmpeg with Rockchip MPP backend.

### Prerequisites

```bash
# Install FFmpeg with Rockchip MPP support
nix-shell -p ffmpeg-rkmpp

# Or install system-wide in configuration.nix:
# environment.systemPackages = [ pkgs.ffmpeg-rkmpp ];
```

### 3.1 Test Video Preparation

Create test videos in various formats:

```bash
# Create test directory
mkdir -p ~/video-tests/{input,output}
cd ~/video-tests

# Download sample videos (or use your own)
# H.264 test clip
wget https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/1080/Big_Buck_Bunny_1080_10s_30MB.mp4 \
  -O input/test_h264.mp4

# H.265/HEVC test clip
wget https://test-videos.co.uk/vids/bigbuckbunny/mp4/h265/1080/Big_Buck_Bunny_1080_10s_30MB.mp4 \
  -O input/test_h265.mp4

# VP9 test clip
wget https://test-videos.co.uk/vids/bigbuckbunny/webm/vp9/1080/Big_Buck_Bunny_1080_10s_20MB.webm \
  -O input/test_vp9.webm

# AV1 test clip (if available)
# AV1 samples may need to be created or sourced separately
```

### 3.2 H.264 Hardware Decode Test

```bash
# Test H.264 hardware decode
ffmpeg -c:v h264_rkmpp -i input/test_h264.mp4 -f null -

# Expected output:
# - Stream mapping showing h264_rkmpp decoder
# - No errors
# - Speed > 1x realtime (typically 3-5x for 1080p)

# Decode with benchmark
ffmpeg -benchmark -c:v h264_rkmpp -i input/test_h264.mp4 -f null -

# Compare with software decode
ffmpeg -benchmark -c:v h264 -i input/test_h264.mp4 -f null -
# Hardware should be 10-20x faster

# Decode to raw YUV (verify output)
ffmpeg -c:v h264_rkmpp -i input/test_h264.mp4 \
  -f rawvideo -pix_fmt yuv420p output/test_h264_decoded.yuv

# Check file size (should be width * height * 1.5 * frame_count)
ls -lh output/test_h264_decoded.yuv
```

### 3.3 H.264 Hardware Encode Test

```bash
# Test H.264 hardware encode from raw video
ffmpeg -f rawvideo -s 1920x1080 -pix_fmt yuv420p -r 30 \
  -i input/test_raw.yuv \
  -c:v h264_rkmpp -b:v 5M -preset ultrafast \
  output/test_h264_hw.mp4

# Encode from decoded video
ffmpeg -i input/test_h264.mp4 \
  -c:v h264_rkmpp -b:v 5M -preset ultrafast \
  output/test_h264_reencoded.mp4

# Expected:
# - Speed > 1x realtime
# - Output file playable
# - Size roughly matches bitrate (5Mbps = ~5MB per 8 seconds)

# Compare quality and speed with software encode
ffmpeg -i input/test_h264.mp4 \
  -c:v libx264 -b:v 5M -preset ultrafast \
  output/test_h264_sw.mp4

# Hardware should be 5-10x faster

# Verify encoded video plays correctly
ffplay output/test_h264_hw.mp4
```

### 3.4 H.265/HEVC Hardware Decode Test

```bash
# Test H.265 hardware decode
ffmpeg -c:v hevc_rkmpp -i input/test_h265.mp4 -f null -

# Expected:
# - Stream mapping showing hevc_rkmpp decoder
# - Speed > 1x realtime (typically 2-4x for 1080p)

# Benchmark comparison
ffmpeg -benchmark -c:v hevc_rkmpp -i input/test_h265.mp4 -f null -
ffmpeg -benchmark -c:v hevc -i input/test_h265.mp4 -f null -
# Hardware should be 10-20x faster

# Decode to raw YUV
ffmpeg -c:v hevc_rkmpp -i input/test_h265.mp4 \
  -f rawvideo -pix_fmt yuv420p output/test_h265_decoded.yuv
```

### 3.5 H.265/HEVC Hardware Encode Test

```bash
# Test H.265 hardware encode
ffmpeg -i input/test_h264.mp4 \
  -c:v hevc_rkmpp -b:v 3M -preset ultrafast \
  output/test_h265_hw.mp4

# Expected:
# - Speed > 1x realtime
# - Better compression than H.264 (smaller file at same quality)

# Compare with software encode
ffmpeg -i input/test_h264.mp4 \
  -c:v libx265 -b:v 3M -preset ultrafast \
  output/test_h265_sw.mp4

# Hardware should be 3-5x faster (HEVC encoding is computationally heavy)

# Verify playback
ffplay output/test_h265_hw.mp4
```

### 3.6 VP9 Hardware Decode Test

**Note:** RK3588 supports VP9 hardware decode only (no encode).

```bash
# Test VP9 hardware decode
ffmpeg -c:v vp9_rkmpp -i input/test_vp9.webm -f null -

# Expected:
# - Stream mapping showing vp9_rkmpp decoder
# - Speed > 1x realtime

# Benchmark comparison
ffmpeg -benchmark -c:v vp9_rkmpp -i input/test_vp9.webm -f null -
ffmpeg -benchmark -c:v libvpx-vp9 -i input/test_vp9.webm -f null -
# Hardware should be 15-25x faster (VP9 software decode is very slow)

# Decode to H.264 for verification
ffmpeg -c:v vp9_rkmpp -i input/test_vp9.webm \
  -c:v h264_rkmpp -b:v 5M \
  output/test_vp9_to_h264.mp4
```

### 3.7 AV1 Hardware Decode Test

**Note:** RK3588 has dedicated AV1 hardware decoder.

```bash
# Test AV1 hardware decode (if av1_rkmpp available)
ffmpeg -c:v av1_rkmpp -i input/test_av1.mp4 -f null -

# Expected:
# - Stream mapping showing av1_rkmpp decoder
# - Speed > 1x realtime

# Benchmark comparison
ffmpeg -benchmark -c:v av1_rkmpp -i input/test_av1.mp4 -f null -
ffmpeg -benchmark -c:v libaom-av1 -i input/test_av1.mp4 -f null -
# Hardware should be 20-40x faster (AV1 software decode is extremely slow)

# Transcode AV1 to H.265 with full hardware pipeline
ffmpeg -c:v av1_rkmpp -i input/test_av1.mp4 \
  -c:v hevc_rkmpp -b:v 3M \
  output/test_av1_to_h265.mp4
```

### 3.8 Multi-Core Codec Test

Test parallel decode/encode across multiple codec cores:

```bash
# Parallel H.264 encode (should use both rkvenc0 and rkvenc1)
ffmpeg -i input/test_h264.mp4 -c:v h264_rkmpp -b:v 5M output/test1.mp4 &
ffmpeg -i input/test_h264.mp4 -c:v h264_rkmpp -b:v 5M output/test2.mp4 &
wait

# Monitor codec usage during parallel jobs
watch -n 1 'cat /proc/mpp_service/rkvenc'

# Should show both cores active with work distributed

# Parallel decode test
ffmpeg -c:v h264_rkmpp -i input/test_h264.mp4 -f null - &
ffmpeg -c:v hevc_rkmpp -i input/test_h265.mp4 -f null - &
wait

# Monitor decoder usage
watch -n 1 'cat /proc/mpp_service/rkvdec'
```

### 3.9 High Resolution Tests (4K)

Test 4K video processing (if you have 4K samples):

```bash
# 4K H.265 decode (RK3588 can handle 4K@60fps)
ffmpeg -c:v hevc_rkmpp -i input/test_4k_h265.mp4 -f null -

# 4K H.264 encode
ffmpeg -i input/test_4k.mp4 \
  -c:v h264_rkmpp -b:v 20M -s 3840x2160 \
  output/test_4k_h264.mp4

# Expected performance:
# - 4K@30fps encode should be realtime or faster
# - 4K@60fps decode should be smooth
```

### 3.10 Codec Stress Test

Continuous encode/decode loop to verify stability:

```bash
# 30-minute stress test script
cat > stress_test_codecs.sh << 'EOF'
#!/usr/bin/env bash
set -e

echo "Starting codec stress test..."
START=$(date +%s)
DURATION=1800  # 30 minutes

while [ $(($(date +%s) - START)) -lt $DURATION ]; do
    echo "=== Test iteration at $(date) ==="

    # H.264 encode/decode cycle
    ffmpeg -y -i input/test_h264.mp4 -c:v h264_rkmpp -b:v 5M /tmp/test_cycle.mp4
    ffmpeg -c:v h264_rkmpp -i /tmp/test_cycle.mp4 -f null -

    # H.265 encode/decode cycle
    ffmpeg -y -i input/test_h264.mp4 -c:v hevc_rkmpp -b:v 3M /tmp/test_cycle_h265.mp4
    ffmpeg -c:v hevc_rkmpp -i /tmp/test_cycle_h265.mp4 -f null -

    # VP9 decode
    ffmpeg -c:v vp9_rkmpp -i input/test_vp9.webm -f null -

    echo "Iteration complete"
done

echo "Stress test completed successfully!"
EOF

chmod +x stress_test_codecs.sh
./stress_test_codecs.sh

# Monitor during stress test:
# - MPP service: cat /proc/mpp_service/rkvdec
# - Temperatures: cat /sys/class/thermal/thermal_zone*/temp
# - dmesg for errors: dmesg -w | grep -i -E "(mpp|rkvdec|rkvenc|rga)"
```

---

## Part 4: MPV Hardware Playback Testing

Test video playback with hardware acceleration in MPV player.

### Install MPV

```bash
nix-shell -p mpv

# Or add to configuration.nix:
# environment.systemPackages = [ pkgs.mpv ];
```

### MPV Configuration

Create `~/.config/mpv/mpv.conf`:

```ini
# Hardware decode using RKMPP
hwdec=rkmpp
hwdec-codecs=all

# Video output optimized for ARM
vo=gpu
gpu-api=opengl
gpu-context=drm

# Performance settings
profile=gpu-hq
video-sync=display-resample

# Logging
msg-level=all=info
```

### Playback Tests

```bash
# Test H.264 playback
mpv input/test_h264.mp4

# Check hardware decode is active
# Press 'i' during playback to show stats
# Should show: "Video: h264 (rkmpp)"

# Test H.265 playback
mpv input/test_h265.mp4
# Should show: "Video: hevc (rkmpp)"

# Test VP9 playback
mpv input/test_vp9.webm
# Should show: "Video: vp9 (rkmpp)"

# Monitor performance
mpv --log-file=mpv_performance.log input/test_h264.mp4

# Check for dropped frames (should be 0)
grep "drop" mpv_performance.log
```

---

## Part 5: RGA3 2D Graphics Testing

Test RGA3 2D graphics acceleration for image operations.

### Install RGA Test Tools

```bash
# If available, install librga or rga-test package
# Otherwise, use FFmpeg with RGA filter support

# Test basic RGA functionality via /dev/rga device
ls -l /dev/rga
# Should be accessible: crw-rw-rw-

# Check RGA capabilities
cat /proc/rga/driver 2>/dev/null || echo "RGA proc not available"
```

### RGA Operations Test

```bash
# Test image scaling with RGA (if RGA filter available in FFmpeg)
# RGA can handle rotation, scaling, format conversion, alpha blending

# Create test image
ffmpeg -f lavfi -i testsrc=size=1920x1080:rate=1 -frames:v 1 test_input.png

# Test scaling (should use RGA hardware)
ffmpeg -i test_input.png -vf scale=3840:2160 test_scaled.png

# Test format conversion
ffmpeg -i test_input.png -pix_fmt rgb24 test_rgb24.png

# Monitor RGA usage
dmesg -w | grep -i rga
# Should show RGA activity during operations
```

### RGA Stress Test

```bash
# Parallel image operations (3 RGA cores should distribute work)
for i in {1..10}; do
    ffmpeg -i test_input.png -vf "scale=1280:720,rotate=PI/4" output_$i.png &
done
wait

# Monitor RGA core usage
dmesg | grep -i "rga3_core" | tail -20
# Should show work distributed across rga3_core0, rga3_core1, rga3_core2
```

---

## Part 6: NPU Testing

Test Neural Processing Unit functionality.

### 6.1 Rocket NPU (Mainline Driver)

```bash
# Check Rocket NPU device
ls -l /dev/accel/accel0
# Expected: crw-rw---- 1 root video

# Check Rocket driver info
cat /sys/class/accel/accel0/device/uevent

# Test basic functionality (requires NPU userspace tools)
# Install rknn-toolkit2 or similar NPU SDK
```

### 6.2 Vendor RKNPU Driver (If Enabled)

```bash
# Check vendor NPU device
ls -l /dev/rknpu
# Expected: crw-rw---- 1 root video

# Check NPU frequency scaling
cat /sys/class/devfreq/fdab0000.npu/cur_freq
cat /sys/class/devfreq/fdab0000.npu/available_frequencies

# Check NPU governor
cat /sys/class/devfreq/fdab0000.npu/governor
```

---

## Part 7: Thermal and Power Management Testing

Monitor thermal behavior and power management under load.

### 7.1 Thermal Monitoring

```bash
# List all thermal zones
for tz in /sys/class/thermal/thermal_zone*/; do
    echo "=== $(basename $tz) ==="
    echo "Type: $(cat $tz/type)"
    echo "Temp: $(cat $tz/temp) ($(awk '{print $1/1000}' $tz/temp)°C)"
    echo "Governor: $(cat $tz/policy 2>/dev/null || echo 'N/A')"
    echo ""
done

# Monitor temperature during load
watch -n 1 'paste <(cat /sys/class/thermal/thermal_zone*/type) <(cat /sys/class/thermal/thermal_zone*/temp) | column -t'
```

### 7.2 CPU Frequency Scaling

```bash
# Check CPU governors
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# Check CPU frequencies
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq

# Monitor during video encode
watch -n 1 'cat /sys/devices/system/cpu/cpu{0,4}/cpufreq/scaling_cur_freq'
# Run encode test in another terminal
ffmpeg -i input/test_h264.mp4 -c:v h264_rkmpp -b:v 5M output/load_test.mp4
```

### 7.3 Memory Frequency Scaling (DMC)

```bash
# Monitor DMC frequency during load
watch -n 1 cat /sys/class/devfreq/dmc/cur_freq

# Run memory-intensive operation
stress-ng --vm 4 --vm-bytes 2G --timeout 60s

# DMC should scale frequency based on memory pressure
```

### 7.4 Power Consumption (If Tools Available)

```bash
# If power monitoring available
cat /sys/class/power_supply/*/uevent

# Monitor during idle vs. load
echo "=== Idle ==="
sleep 10

echo "=== Video Encode Load ==="
ffmpeg -i input/test_h264.mp4 -c:v hevc_rkmpp -b:v 5M /tmp/power_test.mp4

# Check for thermal throttling
dmesg | grep -i -E "(throttle|thermal)"
```

---

## Part 8: Stress Testing

Combined stress test of all subsystems.

### 8.1 Full System Stress Test

```bash
# Create comprehensive stress test script
cat > full_system_stress.sh << 'EOF'
#!/usr/bin/env bash
set -e

echo "=== Starting Full System Stress Test ==="
echo "Duration: 15 minutes"
echo "Press Ctrl+C to stop"
echo ""

START=$(date +%s)
DURATION=900  # 15 minutes

# Function to monitor system health
monitor_health() {
    while true; do
        echo "=== $(date) ==="

        # Temperatures
        echo "Temperatures:"
        for tz in /sys/class/thermal/thermal_zone*/temp; do
            temp=$(cat $tz)
            zone=$(basename $(dirname $tz))
            printf "  %s: %.1f°C\n" "$zone" "$(echo "scale=1; $temp/1000" | bc)"
        done

        # CPU frequencies
        echo "CPU Frequencies:"
        for cpu in 0 4; do
            freq=$(cat /sys/devices/system/cpu/cpu$cpu/cpufreq/scaling_cur_freq)
            printf "  CPU%d: %d MHz\n" "$cpu" "$((freq/1000))"
        done

        # Memory frequency
        echo "Memory Frequency:"
        dmc_freq=$(cat /sys/class/devfreq/dmc/cur_freq)
        printf "  DMC: %d MHz\n" "$((dmc_freq/1000000))"

        # Load average
        echo "Load: $(cat /proc/loadavg | awk '{print $1, $2, $3}')"

        echo ""
        sleep 5
    done
}

# Start health monitoring in background
monitor_health &
MONITOR_PID=$!

# Cleanup on exit
trap "kill $MONITOR_PID 2>/dev/null; echo 'Stress test stopped.'; exit" EXIT INT TERM

# Video encode stress (2 parallel jobs)
while [ $(($(date +%s) - START)) -lt $DURATION ]; do
    echo "Starting video encode cycle..."

    ffmpeg -y -loglevel error -i input/test_h264.mp4 \
        -c:v h264_rkmpp -b:v 5M /tmp/stress_h264.mp4 &

    ffmpeg -y -loglevel error -i input/test_h264.mp4 \
        -c:v hevc_rkmpp -b:v 3M /tmp/stress_h265.mp4 &

    wait

    echo "Starting video decode cycle..."
    ffmpeg -loglevel error -c:v h264_rkmpp -i /tmp/stress_h264.mp4 -f null - &
    ffmpeg -loglevel error -c:v hevc_rkmpp -i /tmp/stress_h265.mp4 -f null - &

    wait

    # Check for errors
    if dmesg | tail -50 | grep -i -q -E "(error|fail|bug|oops)"; then
        echo "ERROR: System errors detected!"
        dmesg | tail -50 | grep -i -E "(error|fail|bug|oops)"
        exit 1
    fi
done

echo "=== Stress Test Completed Successfully ==="
EOF

chmod +x full_system_stress.sh
./full_system_stress.sh
```

### 8.2 Check for System Errors

```bash
# Check for errors in kernel log
dmesg | grep -i -E "(error|fail|bug|oops|panic|segfault)"

# Check for codec errors
dmesg | grep -i -E "(mpp|rkvdec|rkvenc|rga)" | grep -i -E "(error|fail)"

# Check for thermal issues
dmesg | grep -i -E "(thermal|throttle|overheat)"

# Check for IOMMU faults
dmesg | grep -i "iommu.*fault"

# Should all be clean or only show normal informational messages
```

---

## Part 9: Troubleshooting

Common issues and solutions.

### 9.1 Codec Devices Not Appearing

**Problem:** `/dev/mpp_service` or `/dev/rkvdec` missing

**Solutions:**
```bash
# Check if MPP driver loaded
lsmod | grep rk_vcodec
# If missing, load manually:
modprobe rk_vcodec

# Check device tree status
cat /proc/device-tree/mpp-srv/status
# Should be "okay", not "disabled"

# Check for module loading errors
dmesg | grep -i mpp

# Verify dependencies loaded
lsmod | grep -E "(rockchip_opp|rockchip_sip|rockchip_system_monitor)"
```

### 9.2 Hardware Decode Not Working

**Problem:** FFmpeg not using hardware decoder

**Solutions:**
```bash
# Check FFmpeg codecs available
ffmpeg -codecs | grep rkmpp
# Should show: h264_rkmpp, hevc_rkmpp, vp9_rkmpp

# If missing, FFmpeg may not be built with RKMPP support
# Try: nix-shell -p ffmpeg-rkmpp

# Check device permissions
ls -l /dev/mpp_service
# Should be readable by your user (usually group video)

# Add user to video group if needed
sudo usermod -a -G video $USER
# Log out and back in
```

### 9.3 RGA3 Device Not Found

**Problem:** `/dev/rga` missing

**Solutions:**
```bash
# Check RGA driver loaded
lsmod | grep rga3
# If missing:
modprobe rga3

# Check device tree
cat /proc/device-tree/rga@fdb60000/status
# Should be "okay"

# Check IOMMU binding
dmesg | grep -i "rga.*iommu"
```

### 9.4 High Temperatures Under Load

**Problem:** Excessive heat during codec stress tests

**Solutions:**
```bash
# Check thermal zones and trip points
cat /sys/class/thermal/thermal_zone*/trip_point_*_temp

# Check cooling devices active
cat /sys/class/thermal/cooling_device*/cur_state

# Ensure proper heatsink/fan installed and functional
# Check fan operation:
cat /sys/class/hwmon/hwmon*/pwm*
cat /sys/class/hwmon/hwmon*/fan*_input

# Reduce clock speeds if necessary
echo "powersave" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
```

### 9.5 Overlay Store Not Mounting

**Problem:** `/nix/store` overlay not active after LVM setup

**Solutions:**
```bash
# Check if overlay store enabled in config
grep "overlayStore.enable" ~/JohnOS/nixos-configurations/rock5c_minimal/default.nix

# Check SSD mount
findmnt /mnt/nix-ssd
# If not mounted, check systemd unit
systemctl status mnt-nix\\x2dssd.mount

# Check btrfs subvolumes mounted
findmnt | grep nix-ssd

# Check overlay mount
systemctl status nix-store.mount

# Check for errors
journalctl -u nix-store.mount
journalctl -u nix-daemon.service

# Manually test overlay mount
sudo mount -t overlay overlay -o lowerdir=/nix/store,upperdir=/mnt/nix-ssd/upper,workdir=/mnt/nix-ssd/work /nix/store
# If successful, check systemd unit configuration
```

### 9.6 Build Failures

**Problem:** Nix builds still failing with "No space left on device"

**Solutions:**
```bash
# Verify overlay store is active
findmnt /nix/store
# Should show: overlay on /nix/store type overlay

# Check SSD space
df -h /mnt/nix-ssd
# Should have ~500GB available

# Check build directory
ls -ld /mnt/nix-ssd/build
# Should be: drwxrwxr-x root nixbld

# Verify nix-daemon is using SSD
systemctl cat nix-daemon.service | grep TMPDIR
# Should show: Environment=TMPDIR=/mnt/nix-ssd/build

# Test build on SSD
sudo -u nixbld1 env TMPDIR=/mnt/nix-ssd/build mktemp -d
# Should create dir in /mnt/nix-ssd/build

# Check for disk errors
dmesg | grep -i -E "(ext4|btrfs|error|i/o)"
smartctl -a /dev/sdd
```

---

## Part 10: Performance Benchmarks

Expected performance targets.

### 10.1 Video Codec Performance

| Operation | Resolution | Expected Speed | Notes |
|-----------|-----------|----------------|-------|
| H.264 Decode | 1080p@30fps | 3-5x realtime | RKVDEC2 |
| H.264 Decode | 4K@30fps | 1.5-2x realtime | RKVDEC2 |
| H.264 Encode | 1080p@30fps | 1.5-2x realtime | RKVENC2 |
| H.264 Encode | 4K@30fps | 0.8-1.2x realtime | RKVENC2 |
| H.265 Decode | 1080p@30fps | 2-4x realtime | RKVDEC2 |
| H.265 Decode | 4K@30fps | 1-1.5x realtime | RKVDEC2 |
| H.265 Encode | 1080p@30fps | 1-1.5x realtime | RKVENC2 |
| H.265 Encode | 4K@30fps | 0.6-1x realtime | RKVENC2 |
| VP9 Decode | 1080p@30fps | 2-3x realtime | RKVDEC2 |
| VP9 Decode | 4K@30fps | 1-1.5x realtime | RKVDEC2 |
| AV1 Decode | 1080p@60fps | 1-2x realtime | AV1DEC |
| AV1 Decode | 4K@30fps | 0.8-1.2x realtime | AV1DEC |

### 10.2 Multi-Core Scaling

- **Parallel encodes**: 2 concurrent 1080p@30fps H.264 encodes should both run at ~1.5x realtime
- **Parallel decodes**: 2 concurrent 1080p@30fps H.265 decodes should both run at ~2x realtime
- **Mixed workload**: 1 encode + 1 decode should not significantly impact each other

### 10.3 Power Consumption Estimates

- **Idle**: 2-3W
- **1080p H.264 encode**: 5-8W (codec cores + memory)
- **4K H.265 encode**: 10-15W (codec cores + memory + CPU)
- **Full stress**: 20-25W (all cores active)

### 10.4 Thermal Behavior

- **Idle**: 35-45°C ambient + heatsink
- **Light load**: 50-60°C (single 1080p encode)
- **Heavy load**: 65-75°C (parallel 4K encodes)
- **Thermal limit**: 85°C (should trigger throttling)
- **Shutdown**: 95°C (critical)

With proper heatsink/fan, sustained heavy load should stabilize at 70-75°C without throttling.

---

## Part 11: Success Criteria

### ✅ Kernel and Drivers

- [ ] Kernel version 6.18.5 running
- [ ] All Rockchip modules loaded without errors
- [ ] `/dev/mpp_service` device present
- [ ] `/dev/rkvdec` and `/dev/rkvenc` devices present
- [ ] `/dev/rga` device present
- [ ] NPU device present (`/dev/accel/accel0` or `/dev/rknpu`)
- [ ] DMC devfreq active
- [ ] No IOMMU faults in dmesg

### ✅ Video Codecs

- [ ] H.264 hardware decode working (3x+ realtime for 1080p)
- [ ] H.264 hardware encode working (1.5x+ realtime for 1080p)
- [ ] H.265/HEVC hardware decode working (2x+ realtime for 1080p)
- [ ] H.265/HEVC hardware encode working (1x+ realtime for 1080p)
- [ ] VP9 hardware decode working (2x+ realtime for 1080p)
- [ ] AV1 hardware decode working (1x+ realtime for 1080p)
- [ ] Multi-core scaling verified (parallel jobs)
- [ ] MPV hardware playback smooth with no dropped frames

### ✅ RGA3 Graphics

- [ ] RGA3 device accessible
- [ ] 3 RGA cores detected
- [ ] Image scaling operations working
- [ ] Parallel operations distributed across cores

### ✅ Power Management

- [ ] Thermal zones reporting correct temperatures
- [ ] CPU frequency scaling working
- [ ] Memory frequency scaling (DMC) working
- [ ] No thermal throttling under reasonable load
- [ ] Temperatures stable under 75°C with heatsink

### ✅ Storage (Overlay Store)

- [ ] LVM reconfiguration completed successfully
- [ ] 50GB cache + 500GB Nix LV created
- [ ] Btrfs subvolumes created (@upper, @work, @build, @cache)
- [ ] Overlay store mounted at `/nix/store`
- [ ] Nix builds using SSD (`TMPDIR=/mnt/nix-ssd/build`)
- [ ] Build performance significantly improved
- [ ] No "No space left on device" errors during builds

### ✅ Stability

- [ ] 15-minute stress test completed without errors
- [ ] No kernel panics or oops
- [ ] No IOMMU faults
- [ ] No codec errors in dmesg
- [ ] System remains responsive under load

---

## Part 12: Useful Commands Reference

### Quick Status Check

```bash
# One-liner to check all critical components
echo "=== Kernel ===" && uname -r && \
echo "=== MPP ===" && ls -l /dev/mpp_service && \
echo "=== Codecs ===" && ls -l /dev/rkvdec* /dev/rkvenc* 2>/dev/null && \
echo "=== RGA ===" && ls -l /dev/rga && \
echo "=== NPU ===" && ls -l /dev/accel/* /dev/rknpu 2>/dev/null && \
echo "=== DMC ===" && cat /sys/class/devfreq/dmc/cur_freq && \
echo "=== Overlay Store ===" && findmnt /nix/store && \
echo "=== Temperatures ===" && \
for tz in /sys/class/thermal/thermal_zone*/temp; do \
    printf "%.1f°C " "$(awk '{print $1/1000}' $tz)"; \
done && echo ""
```

### Watch System Health

```bash
# Real-time monitoring dashboard
watch -n 1 'echo "=== Temperatures ==="; \
paste <(cat /sys/class/thermal/thermal_zone*/type) \
      <(awk "{printf \"%.1f°C\n\", \$1/1000}" /sys/class/thermal/thermal_zone*/temp) | column -t; \
echo ""; \
echo "=== CPU Freq ==="; \
paste <(echo "CPU0:" "CPU4:") \
      <(awk "{printf \"%d MHz\n\", \$1/1000}" /sys/devices/system/cpu/cpu{0,4}/cpufreq/scaling_cur_freq); \
echo ""; \
echo "=== DMC Freq ==="; \
awk "{printf \"%d MHz\n\", \$1/1000000}" /sys/class/devfreq/dmc/cur_freq; \
echo ""; \
echo "=== Load ==="; \
cat /proc/loadavg | awk "{print \$1, \$2, \$3}"'
```

### Continuous dmesg Monitoring

```bash
# Monitor for codec/driver errors
dmesg -w | grep -i --color=always -E "(mpp|rkvdec|rkvenc|rga|npu|iommu|error|fail|warn)"
```

### Quick Codec Test

```bash
# Single command to test all codecs
for codec in h264_rkmpp hevc_rkmpp vp9_rkmpp; do
    echo "Testing $codec..."
    ffmpeg -c:v $codec -i input/test_*.{mp4,webm} -f null - 2>&1 | grep -E "(Stream|speed)"
done
```

---

## Summary

This testing guide provides comprehensive verification of:

1. **Storage reconfiguration** (LVM + overlay store)
2. **Kernel driver initialization**
3. **Hardware video codec acceleration** (H.264, H.265, VP9, AV1)
4. **2D graphics acceleration** (RGA3)
5. **Neural processing** (NPU)
6. **Power and thermal management**
7. **System stability under stress**

Follow the sections in order, starting with the LVM reconfiguration, then proceed through driver verification, codec testing, and stress testing. Each section includes expected results and troubleshooting steps.

After completing all tests successfully, your Rock 5C will have:
- Full hardware-accelerated video encode/decode
- Fast SSD-backed Nix builds via overlay store
- Optimized power management
- Verified system stability

**Good luck with your testing!**
