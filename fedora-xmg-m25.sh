#!/bin/bash
# ============================================================
# Tuxedo Drivers + Schenker DMI Patch Installer (v4.5)
# Deep Cleaning + Multi-Kernel Support + GCC 14 Patching
# Collaboration: Gemini CLI + Claude AI (Peer Reviewed)
# ============================================================

set -euo pipefail

RUNNING_KERNEL=$(uname -r)
echo "============================================================"
echo " Tuxedo Drivers + Schenker Patch Installer (v4.5)"
echo " Running kernel: ${RUNNING_KERNEL}"
echo "============================================================"
echo

# ------------------------------------------------------------
# Step 1 - Kill TCC & Dependencies
# ------------------------------------------------------------
echo "[1/7] stopping TUXEDO Control Center & preparing system..."
pkill -f tuxedo-control-center || true

sudo dnf install -y git dkms make gcc fedora-repos-archive python3

# Fetch exact headers. Enabling updates-archive ensures older ISO kernels find a match.
sudo dnf install -y --enablerepo=updates-archive \
    "kernel-devel-${RUNNING_KERNEL}" \
    "kernel-headers-${RUNNING_KERNEL}" || {
    echo "⚠️ Exact kernel-devel not found. Falling back to latest..."
    sudo dnf install -y kernel-devel kernel-headers
}
echo "✅ Dependencies ready."
echo

# ------------------------------------------------------------
# Step 2 - Deep Cleanup of Legacy / Broken States
# ------------------------------------------------------------
echo "[2/7] Deep cleaning legacy tuxedo-drivers states..."

# 1. Unregister all versions from DKMS (including broken ones)
DKMS_VERSIONS=$(dkms status -m tuxedo-drivers | awk -F'[/,: ]+' '{print $2}' | sort -u)
for v in $DKMS_VERSIONS; do
    echo "  → Removing DKMS registration for version: $v"
    sudo dkms remove -m tuxedo-drivers -v "$v" --all 2>/dev/null || true
done

# 2. Remove all source directories and symlinks in /usr/src
echo "  → Purging /usr/src/tuxedo-drivers-*..."
sudo find /usr/src -maxdepth 1 -name "tuxedo-drivers-*" | while read -r dir; do
    echo "    - Deleting legacy source: $dir"
    sudo rm -rf "$dir"
done

echo "✅ System sanitized."
echo

# ------------------------------------------------------------
# Step 3 - Clone / Update Repository safely in /tmp
# ------------------------------------------------------------
echo "[3/7] Fetching latest tuxedo-drivers source..."
WORK_DIR="/tmp/tuxedo-drivers-build"
sudo rm -rf "$WORK_DIR"
git clone https://gitlab.com/tuxedocomputers/development/packages/tuxedo-drivers.git "$WORK_DIR"
cd "$WORK_DIR"

# Dynamically pull the version
DKMS_VERSION=$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "99.99.99")
echo "  → Target Version: ${DKMS_VERSION}"
echo "✅ Repository ready."
echo

# ------------------------------------------------------------
# Step 4 - Kernel API Fixes & Schenker DMI Patch
# ------------------------------------------------------------
echo "[4/7] Applying Source Patches..."

# FIX: Intel Atom header naming mismatch
find . -type f -name "*.c" -exec sed -i 's/INTEL_ATOM_AIRMONT_MID/INTEL_ATOM_AIRMONT_NP/g' {} +

# FIX: GCC 14 strict pointer enforcement
if [ -f "src/clevo_acpi.c" ]; then
    sed -i '/\.owner = THIS_MODULE,/d' src/clevo_acpi.c
fi

# FIX: DMI Gatekeeper Bypass for Schenker hardware
PATCH_FILE="src/tuxedo_compatibility_check/tuxedo_compatibility_check.c"

if [ ! -f "$PATCH_FILE" ]; then
    echo "❌ Patch target not found: $PATCH_FILE"
    exit 1
fi

python3 - "$PATCH_FILE" <<'PYEOF'
import sys, re

path = sys.argv[1]
with open(path, 'r') as f:
    content = f.read()

# The entry we want to insert
new_entry = (
    '\t{\n'
    '\t\t.matches = {\n'
    '\t\t\tDMI_MATCH(DMI_SYS_VENDOR, "SchenkerTechnologiesGmbH"),\n'
    '\t\t},\n'
    '\t},\n'
)

# Search for the TUXEDO chassis vendor entry to anchor our patch
pattern = re.compile(
    r'DMI_MATCH\s*\(\s*DMI_CHASSIS_VENDOR\s*,\s*"TUXEDO"\s*\)'
    r'[^}]*}'    
    r'[^}]*},',  
    re.DOTALL
)

m = pattern.search(content)
if not m:
    # Try alternate anchor if first one fails
    pattern = re.compile(r'static\s+const\s+struct\s+dmi_system_id\s+tuxedo_whitelist\s*\[\]\s*=\s*\{', re.DOTALL)
    m = pattern.search(content)
    if not m:
        print("ERROR: Could not locate patch anchor")
        sys.exit(1)
    insert_pos = m.end()
else:
    insert_pos = m.end()

if content[insert_pos] != '\n':
    new_entry = '\n' + new_entry
content = content[:insert_pos] + '\n' + new_entry + content[insert_pos:]

with open(path, 'w') as f:
    f.write(content)

print("DMI Patch inserted successfully.")
PYEOF

# NEW: XMG Pro 16 VE (M25) Power Limit Customization
echo "  → Applying M25 Power Limit Customization..."

# Patch tuxedo_io.c
TDP_FILE="src/tuxedo_io/tuxedo_io.c"
python3 - "$TDP_FILE" <<'PYEOF'
import sys, re
path = sys.argv[1]
with open(path, 'r') as f:
    content = f.read()

# Add TDP definitions
if 'tdp_min_x6pr5xx' not in content:
    defs = (
        'static int tdp_min_x6pr5xx[] = { 0x0a, 0x0a, 0x0a };\n'
        'static int tdp_max_x6pr5xx[] = { 0x91, 0x91, 0xc8 };\n\n'
    )
    content = re.sub(r'(static int \*tdp_min_defs = NULL;)', defs + r'\1', content)

# Add DMI matching
match_entry = (
    '\n\t} else if (dmi_match(DMI_BOARD_NAME, "X6PR5xxW_X6RP5xxW")) {\n'
    '\t\ttdp_min_defs = tdp_min_x6pr5xx;\n'
    '\t\ttdp_max_defs = tdp_max_x6pr5xx;'
)
if 'X6PR5xxW_X6RP5xxW' not in content:
    # Match the block content BEFORE the closing brace
    pattern = re.compile(r'(dmi_match\(DMI_BOARD_NAME, "X6KK45xU_X6SP45xU"\)\) \{[^}]*)', re.DOTALL)
    content = pattern.sub(r'\1' + match_entry, content)

with open(path, 'w') as f:
    f.write(content)
print("TDP Patch applied.")
PYEOF

# Patch uniwill_keyboard.h
KBD_FILE="src/uniwill_keyboard.h"
python3 - "$KBD_FILE" <<'PYEOF'
import sys, re
path = sys.argv[1]
with open(path, 'r') as f:
    content = f.read()

# Add to uniwill_custom_profile_mode_needed
if 'X6PR5xxW_X6RP5xxW' not in content:
    # Insert before the last #endif in the custom profile block
    pattern = re.compile(r'(\|\| dmi_match\(DMI_BOARD_NAME, "X5AR45xS"\)\n)(#endif)', re.DOTALL)
    content = pattern.sub(r'\1\t\t|| dmi_match(DMI_BOARD_NAME, "X6PR5xxW_X6RP5xxW")\n\2', content)

with open(path, 'w') as f:
    f.write(content)
print("Keyboard/Custom Profile Patch applied.")
PYEOF

# Patch src/clevo_leds.h to disable ACPI LEDs for X6PR5xxW_X6RP5xxW to avoid name collisions
LEDS_FILE="src/clevo_leds.h"
if [ -f "$LEDS_FILE" ]; then
    echo "  → Applying Clevo LEDs conflict patch..."
    python3 - "$LEDS_FILE" <<'PYEOF'
import sys
path = sys.argv[1]
with open(path, 'r') as f:
    content = f.read()

early_return = (
    'int clevo_leds_init(struct platform_device *dev)\n'
    '{\n'
    '\tif (dmi_match(DMI_BOARD_NAME, "X6PR5xxW_X6RP5xxW")) {\n'
    '\t\tpr_info("tuxedo_keyboard: Disabling ACPI LEDs for per-key RGB compatibility\\n");\n'
    '\t\treturn 0;\n'
    '\t}\n'
)

if 'Disabling ACPI LEDs for per-key RGB compatibility' not in content:
    content = content.replace('int clevo_leds_init(struct platform_device *dev)\n{', early_return)

with open(path, 'w') as f:
    f.write(content)
PYEOF
fi

# Patch src/uniwill_leds.h to disable ACPI LEDs for X6PR5xxW_X6RP5xxW to avoid name collisions
UW_LEDS_FILE="src/uniwill_leds.h"
if [ -f "$UW_LEDS_FILE" ]; then
    echo "  → Applying Uniwill LEDs conflict patch..."
    python3 - "$UW_LEDS_FILE" <<'PYEOF'
import sys
path = sys.argv[1]
with open(path, 'r') as f:
    content = f.read()

early_return = (
    'int uniwill_leds_init(struct platform_device *dev)\n'
    '{\n'
    '\tif (dmi_match(DMI_BOARD_NAME, "X6PR5xxW_X6RP5xxW")) {\n'
    '\t\tpr_info("tuxedo_keyboard: Disabling ACPI LEDs in uniwill_leds for per-key RGB compatibility\\n");\n'
    '\t\treturn 0;\n'
    '\t}\n'
)

if 'Disabling ACPI LEDs in uniwill_leds for per-key RGB compatibility' not in content:
    content = content.replace('int uniwill_leds_init(struct platform_device *dev)\n{', early_return)

with open(path, 'w') as f:
    f.write(content)
PYEOF
fi


grep -q "SchenkerTechnologiesGmbH" "$PATCH_FILE" || {
    echo "❌ DMI Patch verification failed."
    exit 1
}
echo "✅ Source patches applied."

echo

# ------------------------------------------------------------
# Step 5 - Build / Install via Native DKMS Pipeline
# ------------------------------------------------------------
echo "[5/7] Registering and building DKMS module..."

# Create or Update dkms.conf
# Note: BUILT_MODULE_LOCATION must point to where the .ko is relative to the build root.
# For modules in src/, it must be src/. For subdirs, it must be src/<subdir>/.
echo "  → Generating robust dkms.conf..."
cat > dkms.conf <<EOF
PACKAGE_NAME="tuxedo-drivers"
PACKAGE_VERSION="${DKMS_VERSION}"
AUTOINSTALL="yes"

BUILT_MODULE_NAME[0]="clevo_acpi"
BUILT_MODULE_LOCATION[0]="src/"
DEST_MODULE_LOCATION[0]="/kernel/lib/"

BUILT_MODULE_NAME[1]="clevo_wmi"
BUILT_MODULE_LOCATION[1]="src/"
DEST_MODULE_LOCATION[1]="/kernel/lib/"

BUILT_MODULE_NAME[2]="tuxedo_keyboard"
BUILT_MODULE_LOCATION[2]="src/"
DEST_MODULE_LOCATION[2]="/kernel/lib/"

BUILT_MODULE_NAME[3]="uniwill_wmi"
BUILT_MODULE_LOCATION[3]="src/"
DEST_MODULE_LOCATION[3]="/kernel/lib/"

BUILT_MODULE_NAME[4]="ite_8291"
BUILT_MODULE_LOCATION[4]="src/ite_8291/"
DEST_MODULE_LOCATION[4]="/kernel/lib/"

BUILT_MODULE_NAME[5]="ite_8291_lb"
BUILT_MODULE_LOCATION[5]="src/ite_8291_lb/"
DEST_MODULE_LOCATION[5]="/kernel/lib/"

BUILT_MODULE_NAME[6]="ite_8297"
BUILT_MODULE_LOCATION[6]="src/ite_8297/"
DEST_MODULE_LOCATION[6]="/kernel/lib/"

BUILT_MODULE_NAME[7]="ite_829x"
BUILT_MODULE_LOCATION[7]="src/ite_829x/"
DEST_MODULE_LOCATION[7]="/kernel/lib/"

BUILT_MODULE_NAME[8]="tuxedo_io"
BUILT_MODULE_LOCATION[8]="src/tuxedo_io/"
DEST_MODULE_LOCATION[8]="/kernel/lib/"

BUILT_MODULE_NAME[9]="tuxedo_compatibility_check"
BUILT_MODULE_LOCATION[9]="src/tuxedo_compatibility_check/"
DEST_MODULE_LOCATION[9]="/kernel/lib/"

BUILT_MODULE_NAME[10]="tuxedo_nb05_keyboard"
BUILT_MODULE_LOCATION[10]="src/tuxedo_nb05/"
DEST_MODULE_LOCATION[10]="/kernel/lib/"

BUILT_MODULE_NAME[11]="tuxedo_nb05_power_profiles"
BUILT_MODULE_LOCATION[11]="src/tuxedo_nb05/"
DEST_MODULE_LOCATION[11]="/kernel/lib/"

BUILT_MODULE_NAME[12]="tuxedo_nb05_ec"
BUILT_MODULE_LOCATION[12]="src/tuxedo_nb05/"
DEST_MODULE_LOCATION[12]="/kernel/lib/"

BUILT_MODULE_NAME[13]="tuxedo_nb05_sensors"
BUILT_MODULE_LOCATION[13]="src/tuxedo_nb05/"
DEST_MODULE_LOCATION[13]="/kernel/lib/"

BUILT_MODULE_NAME[14]="tuxedo_nb04_keyboard"
BUILT_MODULE_LOCATION[14]="src/tuxedo_nb04/"
DEST_MODULE_LOCATION[14]="/kernel/lib/"

BUILT_MODULE_NAME[15]="tuxedo_nb04_wmi_ab"
BUILT_MODULE_LOCATION[15]="src/tuxedo_nb04/"
DEST_MODULE_LOCATION[15]="/kernel/lib/"

BUILT_MODULE_NAME[16]="tuxedo_nb04_wmi_bs"
BUILT_MODULE_LOCATION[16]="src/tuxedo_nb04/"
DEST_MODULE_LOCATION[16]="/kernel/lib/"

BUILT_MODULE_NAME[17]="tuxedo_nb04_sensors"
BUILT_MODULE_LOCATION[17]="src/tuxedo_nb04/"
DEST_MODULE_LOCATION[17]="/kernel/lib/"

BUILT_MODULE_NAME[18]="tuxedo_nb04_power_profiles"
BUILT_MODULE_LOCATION[18]="src/tuxedo_nb04/"
DEST_MODULE_LOCATION[18]="/kernel/lib/"

BUILT_MODULE_NAME[19]="tuxedo_nb04_kbd_backlight"
BUILT_MODULE_LOCATION[19]="src/tuxedo_nb04/"
DEST_MODULE_LOCATION[19]="/kernel/lib/"

BUILT_MODULE_NAME[20]="tuxedo_nb05_kbd_backlight"
BUILT_MODULE_LOCATION[20]="src/tuxedo_nb05/"
DEST_MODULE_LOCATION[20]="/kernel/lib/"

BUILT_MODULE_NAME[21]="tuxedo_nb02_nvidia_power_ctrl"
BUILT_MODULE_LOCATION[21]="src/tuxedo_nb02_nvidia_power_ctrl/"
DEST_MODULE_LOCATION[21]="/kernel/lib/"

BUILT_MODULE_NAME[22]="tuxedo_nb05_fan_control"
BUILT_MODULE_LOCATION[22]="src/tuxedo_nb05/"
DEST_MODULE_LOCATION[22]="/kernel/lib/"

BUILT_MODULE_NAME[23]="tuxi_acpi"
BUILT_MODULE_LOCATION[23]="src/tuxedo_tuxi/"
DEST_MODULE_LOCATION[23]="/kernel/lib/"

BUILT_MODULE_NAME[24]="tuxedo_tuxi_fan_control"
BUILT_MODULE_LOCATION[24]="src/tuxedo_tuxi/"
DEST_MODULE_LOCATION[24]="/kernel/lib/"

BUILT_MODULE_NAME[25]="stk8321"
BUILT_MODULE_LOCATION[25]="src/stk8321/"
DEST_MODULE_LOCATION[25]="/kernel/lib/"

BUILT_MODULE_NAME[26]="gxtp7380"
BUILT_MODULE_LOCATION[26]="src/gxtp7380/"
DEST_MODULE_LOCATION[26]="/kernel/lib/"
EOF

# Deploy sources to /usr/src
sudo cp -r "$WORK_DIR" "/usr/src/tuxedo-drivers-${DKMS_VERSION}"

# DKMS Cycle - Pinning to RUNNING_KERNEL to avoid "built but not installed"
sudo dkms add -m tuxedo-drivers -v "${DKMS_VERSION}"
sudo dkms build -m tuxedo-drivers -v "${DKMS_VERSION}" -k "${RUNNING_KERNEL}"
sudo dkms install --force -m tuxedo-drivers -v "${DKMS_VERSION}" -k "${RUNNING_KERNEL}"

echo "✅ DKMS installation successful."
echo

# ------------------------------------------------------------
# Step 6 - Kernel Module Refresh
# ------------------------------------------------------------
echo "[6/7] Reloading kernel modules..."
for m in tuxedo_keyboard tuxedo_compatibility_check tuxedo_io tuxedo_nb02_nvidia_power_ctrl ite_8291 ite_8291_lb ite_8297 ite_829x
do
    sudo modprobe -r "$m" 2>/dev/null || true
done

sudo modprobe ite_8291 2>/dev/null || true
sudo modprobe tuxedo_compatibility_check
sudo modprobe tuxedo_keyboard
sudo modprobe tuxedo_io
sudo modprobe tuxedo_nb02_nvidia_power_ctrl 2>/dev/null || true

# Reset the USB device to force a re-bind if it was detached by a crashed app
ITE_USB_DEV=$(grep -l "048d" /sys/bus/usb/devices/*/idVendor 2>/dev/null | head -n 1 | xargs dirname)
if [ -n "$ITE_USB_DEV" ] && [ -d "$ITE_USB_DEV" ]; then
    echo "  → Resetting ITE USB device at ${ITE_USB_DEV}..."
    echo 0 | sudo tee "${ITE_USB_DEV}/authorized" >/dev/null || true
    sleep 1
    echo 1 | sudo tee "${ITE_USB_DEV}/authorized" >/dev/null || true
    sleep 1
fi

# Conflict Prevention: Disable TCC keyboard backlight control if XMG Backlight app is installed
if [ -d "/usr/share/xmg-backlight" ] && [ -f "/etc/tcc/settings" ]; then
    echo "  → XMG Backlight Management detected. Disabling TCC keyboard control to prevent conflicts..."
    sudo sed -i 's/"keyboardBacklightControlEnabled":true/"keyboardBacklightControlEnabled":false/g' /etc/tcc/settings || true
fi

echo "  → Restarting TUXEDO Control Center Service..."
sudo systemctl restart tccd.service || true


echo "✅ Drivers reloaded."
echo

# ------------------------------------------------------------
# Step 7 - TCC GPU Fix (GPU-Aware Desktop Patching)
# ------------------------------------------------------------
echo "[7/7] Applying TCC stability fixes (GPU-Aware)..."

# Detection logic
HAS_NVIDIA=false
NV_MAJOR=0
if lspci | grep -iq nvidia; then
    HAS_NVIDIA=true
    NV_VER=$(modinfo -F version nvidia 2>/dev/null || echo "0")
    NV_MAJOR=$(echo "$NV_VER" | cut -d. -f1)
fi

TCC_FLAGS="--ozone-platform-hint=auto"

# If NOT a modern NVIDIA driver, fallback to disabling GPU
if [ "$HAS_NVIDIA" = true ] && [ "$NV_MAJOR" -ge 545 ]; then
    echo "  → Modern NVIDIA driver detected ($NV_VER). Enabling GPU acceleration."
else
    echo "  → Non-NVIDIA or older driver detected. Using --disable-gpu for stability."
    TCC_FLAGS="$TCC_FLAGS --disable-gpu"
fi

TCC_DESKTOP_FILES=$(find /usr/share/applications "$HOME/.config/autostart" /opt/tuxedo-control-center -name "tuxedo-control-center*.desktop" 2>/dev/null || true)

for f in $TCC_DESKTOP_FILES; do
    echo "  → Patching $f..."
    if [ -w "$f" ]; then
        # Clean existing flags first to prevent duplication
        sed -Ei 's/ --ozone-platform-hint=auto//g; s/ --disable-gpu//g' "$f"
        # Inject new flags after the binary path
        sed -Ei "s@^Exec=([^ ]+)@Exec=\1 $TCC_FLAGS@" "$f"
    else
        sudo sed -Ei 's/ --ozone-platform-hint=auto//g; s/ --disable-gpu//g' "$f"
        sudo sed -Ei "s@^Exec=([^ ]+)@Exec=\1 $TCC_FLAGS@" "$f"
    fi
done

# Clean up legacy system-wide wayland hints that break Electron keyrings (e.g. agy login)
if [ -f "/etc/profile.d/tcc-stability.sh" ]; then
    sudo rm -f /etc/profile.d/tcc-stability.sh
fi


echo
echo "============================================================"
echo "🎉 Robust Installation Complete (v4.5)!"
echo "Drivers are active, and TCC is patched with GPU-awareness."
echo "Hardware acceleration is: $( [ "$HAS_NVIDIA" = true ] && [ "$NV_MAJOR" -ge 545 ] && echo "ENABLED" || echo "DISABLED" )"
echo "============================================================"

