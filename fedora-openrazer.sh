#!/bin/bash
# ============================================================
# OpenRazer PR #2817 Installer – Mouse Dock Pro Passthrough
# For Fedora (tested on F44)
# Installs karaktaka's branch with full dock-to-mouse relay
# https://github.com/openrazer/openrazer/pull/2817
# ============================================================

set -euo pipefail

RUNNING_KERNEL=$(uname -r)
PR_BRANCH="feature/mouse-dock-pro-consolidated"
PR_REPO="https://github.com/karaktaka/openrazer.git"
WORK_DIR="/tmp/openrazer-pr2817-build"
BACKUP_DIR="/var/lib/openrazer-backup"
DKMS_NAME="openrazer-driver"
DKMS_OLD_VER="3.12.4"
DKMS_NEW_VER="3.12.4.pr2817"
PYSITE="/usr/lib/python3.14/site-packages"

# What action to run
ACTION="${1:-install}"

echo "============================================================"
echo " OpenRazer PR #2817 – Mouse Dock Pro Passthrough"
echo " Running kernel: ${RUNNING_KERNEL}"
echo " Action: ${ACTION}"
echo "============================================================"
echo

# ============================================================
# ROLLBACK MODE
# ============================================================
if [ "$ACTION" = "rollback" ]; then
    echo "[ROLLBACK] Restoring original OpenRazer 3.12.4..."

    if [ ! -d "$BACKUP_DIR" ]; then
        echo "❌ No backup found at $BACKUP_DIR. Cannot rollback."
        exit 1
    fi

    # 1. Stop daemon
    echo "  → Stopping openrazer-daemon..."
    systemctl --user stop openrazer-daemon.service 2>/dev/null || true
    sleep 1

    # 2. Unload kernel modules
    echo "  → Unloading kernel modules..."
    for m in razermouse razeraccessory razerkbd razerkraken; do
        sudo modprobe -r "$m" 2>/dev/null || true
    done

    # 3. Remove PR DKMS module
    echo "  → Removing PR DKMS module..."
    sudo dkms remove -m "$DKMS_NAME" -v "$DKMS_NEW_VER" --all 2>/dev/null || true
    sudo rm -rf "/usr/src/${DKMS_NAME}-${DKMS_NEW_VER}"

    # 4. Restore original DKMS source
    echo "  → Restoring original driver source..."
    sudo cp -a "$BACKUP_DIR/openrazer-driver-${DKMS_OLD_VER}" "/usr/src/${DKMS_NAME}-${DKMS_OLD_VER}"

    # 5. Rebuild original DKMS
    echo "  → Rebuilding original DKMS module..."
    sudo dkms add -m "$DKMS_NAME" -v "$DKMS_OLD_VER" 2>/dev/null || true
    sudo dkms build -m "$DKMS_NAME" -v "$DKMS_OLD_VER" -k "$RUNNING_KERNEL"
    sudo dkms install --force -m "$DKMS_NAME" -v "$DKMS_OLD_VER" -k "$RUNNING_KERNEL"

    # 6. Restore Python packages
    echo "  → Restoring daemon Python package..."
    sudo cp -a "$BACKUP_DIR/openrazer_daemon/"* "${PYSITE}/openrazer_daemon/"
    echo "  → Restoring client Python package..."
    sudo cp -a "$BACKUP_DIR/openrazer/"* "${PYSITE}/openrazer/"

    # 7. Load modules & start daemon
    echo "  → Loading kernel modules..."
    sudo modprobe razeraccessory 2>/dev/null || true
    sudo modprobe razermouse 2>/dev/null || true
    sleep 1
    echo "  → Starting openrazer-daemon..."
    systemctl --user start openrazer-daemon.service

    echo
    echo "============================================================"
    echo "✅ Rollback complete. Original OpenRazer ${DKMS_OLD_VER} restored."
    echo "============================================================"
    exit 0
fi

# ============================================================
# INSTALL MODE
# ============================================================

# ------------------------------------------------------------
# Step 1 – Prerequisites
# ------------------------------------------------------------
echo "[1/8] Checking prerequisites..."
sudo dnf install -y --enablerepo=updates-archive \
    git dkms make gcc \
    "kernel-devel-${RUNNING_KERNEL}" 2>/dev/null || \
    sudo dnf install -y git dkms make gcc kernel-devel
echo "✅ Dependencies ready."
echo

# ------------------------------------------------------------
# Step 2 – Clone PR Branch
# ------------------------------------------------------------
echo "[2/8] Fetching PR #2817 source..."
sudo rm -rf "$WORK_DIR"
git clone --branch "$PR_BRANCH" --single-branch "$PR_REPO" "$WORK_DIR"
echo "  → Branch: $PR_BRANCH"
echo "  → Commit: $(cd "$WORK_DIR" && git rev-parse --short HEAD)"
echo "✅ Source ready."
echo

# ------------------------------------------------------------
# Step 3 – Stop Daemon
# ------------------------------------------------------------
echo "[3/8] Stopping openrazer-daemon..."
REAL_USER="${SUDO_USER:-$USER}"
REAL_UID=$(id -u "$REAL_USER" 2>/dev/null || echo "")
if [ -n "$REAL_USER" ] && [ "$REAL_USER" != "root" ] && [ -n "$REAL_UID" ]; then
    sudo -u "$REAL_USER" XDG_RUNTIME_DIR="/run/user/$REAL_UID" systemctl --user stop openrazer-daemon.service 2>/dev/null || true
else
    systemctl --user stop openrazer-daemon.service 2>/dev/null || true
fi
sleep 1
echo "✅ Daemon stopped."
echo

# ------------------------------------------------------------
# Step 4 – Backup Current Installation
# ------------------------------------------------------------
echo "[4/8] Backing up current OpenRazer ${DKMS_OLD_VER}..."
sudo mkdir -p "$BACKUP_DIR"

# Backup DKMS source
if [ -d "/usr/src/${DKMS_NAME}-${DKMS_OLD_VER}" ]; then
    sudo cp -a "/usr/src/${DKMS_NAME}-${DKMS_OLD_VER}" "$BACKUP_DIR/"
    echo "  → Driver source backed up"
fi

# Backup daemon Python package
sudo cp -a "${PYSITE}/openrazer_daemon" "$BACKUP_DIR/"
echo "  → Daemon package backed up"

# Backup client Python package
sudo cp -a "${PYSITE}/openrazer" "$BACKUP_DIR/"
echo "  → Client package backed up"

echo "✅ Backup saved to $BACKUP_DIR"
echo

# ------------------------------------------------------------
# Step 5 – Unload Old Kernel Modules & Remove Old DKMS
# ------------------------------------------------------------
echo "[5/8] Removing old kernel modules..."

# Unload
for m in razermouse razeraccessory razerkbd razerkraken; do
    sudo modprobe -r "$m" 2>/dev/null || true
done
echo "  → Modules unloaded"

# Remove old DKMS registration
sudo dkms remove -m "$DKMS_NAME" -v "$DKMS_OLD_VER" --all 2>/dev/null || true
echo "  → Old DKMS entry removed"

echo "✅ Old modules cleaned."
echo

# ------------------------------------------------------------
# Step 6 – Install New DKMS Driver from PR
# ------------------------------------------------------------
echo "[6/8] Installing PR driver via DKMS..."

# Prepare source directory
NEW_SRC="/usr/src/${DKMS_NAME}-${DKMS_NEW_VER}"
sudo rm -rf "$NEW_SRC"
sudo mkdir -p "$NEW_SRC"

# Copy driver source and top-level Makefile (needed by DKMS make command)
sudo cp -a "$WORK_DIR/driver" "$NEW_SRC/"
sudo cp -a "$WORK_DIR/Makefile" "$NEW_SRC/"

# Write dkms.conf with our custom version
cat <<DKMSEOF | sudo tee "$NEW_SRC/dkms.conf" > /dev/null
PACKAGE_NAME="openrazer-driver"
PACKAGE_VERSION="${DKMS_NEW_VER}"
AUTOINSTALL="yes"
MAKE="KERNELDIR=/lib/modules/\${kernelver}/build make driver"

BUILT_MODULE_NAME[0]="razerkbd"
BUILT_MODULE_NAME[1]="razermouse"
BUILT_MODULE_NAME[2]="razerkraken"
BUILT_MODULE_NAME[3]="razeraccessory"

BUILT_MODULE_LOCATION[0]="driver"
BUILT_MODULE_LOCATION[1]="driver"
BUILT_MODULE_LOCATION[2]="driver"
BUILT_MODULE_LOCATION[3]="driver"

DEST_MODULE_LOCATION[0]="/kernel/drivers/hid"
DEST_MODULE_LOCATION[1]="/kernel/drivers/hid"
DEST_MODULE_LOCATION[2]="/kernel/drivers/hid"
DEST_MODULE_LOCATION[3]="/kernel/drivers/hid"
DKMSEOF

# DKMS cycle (remove first in case of re-run)
sudo dkms remove -m "$DKMS_NAME" -v "$DKMS_NEW_VER" --all 2>/dev/null || true
sudo dkms add -m "$DKMS_NAME" -v "$DKMS_NEW_VER"
sudo dkms build -m "$DKMS_NAME" -v "$DKMS_NEW_VER" -k "$RUNNING_KERNEL"
sudo dkms install --force -m "$DKMS_NAME" -v "$DKMS_NEW_VER" -k "$RUNNING_KERNEL"

echo "✅ DKMS driver installed (version ${DKMS_NEW_VER})."
echo

# ------------------------------------------------------------
# Step 7 – Install Daemon & Python Library from PR
# ------------------------------------------------------------
echo "[7/8] Installing daemon & Python library from PR..."

# Overlay daemon Python files
sudo cp -a "$WORK_DIR/daemon/openrazer_daemon/"* "${PYSITE}/openrazer_daemon/"
echo "  → Daemon files installed"

# Overlay client Python files
sudo cp -a "$WORK_DIR/pylib/openrazer/"* "${PYSITE}/openrazer/"
echo "  → Client library installed"

# Apply patch: Default fallback DPI 1600 instead of 1800
sudo sed -i 's/self\.dpi = \[1800, 1800\]/self.dpi = [1600, 1600]/g' "${PYSITE}/openrazer_daemon/hardware/device_base.py"
echo "  → Patched OpenRazer startup default DPI to 1600"

# Apply patch: Fix Polychromatic hardcoded stage 1 (400 DPI) bug on 'Sync Now'
POLY_BACKEND="${PYSITE}/polychromatic/backends/openrazer.py"
if [ -f "$POLY_BACKEND" ]; then
    sudo python3 - <<'PYEOF'
path = "/usr/lib/python3.14/site-packages/polychromatic/backends/openrazer.py"
with open(path, "r") as f:
    content = f.read()

old_sync = """            def sync(self, stages):
                \"\"\"OpenRazer's "dpi_stages" setter expects: [active_stage, [stages: (x,y), (x,y)]\"\"\"
                stages = [(stage[0], stage[1]) for stage in stages]
                self._rdevice.dpi_stages = (1, stages)"""

new_sync = """            def sync(self, stages):
                \"\"\"OpenRazer's "dpi_stages" setter expects: [active_stage, [stages: (x,y), (x,y)]\"\"\"
                stages = [(stage[0], stage[1]) for stage in stages]
                active_stage = 1
                try:
                    cur_dpi = self._rdevice.dpi[0]
                    for idx, s in enumerate(stages, start=1):
                        if s[0] == cur_dpi:
                            active_stage = idx
                            break
                    else:
                        active_stage = self._rdevice.dpi_stages[0]
                except Exception:
                    active_stage = 1
                self._rdevice.dpi_stages = (active_stage, stages)"""

if old_sync in content:
    content = content.replace(old_sync, new_sync)
    with open(path, "w") as f:
        f.write(content)
    print("  → Patched Polychromatic DPI stage sync bug")
PYEOF
fi

# Recompile .pyc cache
sudo python3 -m compileall -q "${PYSITE}/openrazer_daemon/" 2>/dev/null || true
sudo python3 -m compileall -q "${PYSITE}/openrazer/" 2>/dev/null || true
sudo python3 -m compileall -q "${PYSITE}/polychromatic/" 2>/dev/null || true
echo "  → Bytecode cache updated"

echo "✅ Python packages installed and patched."
echo

# ------------------------------------------------------------
# Step 8 – Load Modules & Start Daemon
# ------------------------------------------------------------
echo "[8/8] Loading new modules and starting daemon..."

sudo modprobe razeraccessory
sudo modprobe razermouse 2>/dev/null || true
sudo modprobe razerkbd 2>/dev/null || true
echo "  → Kernel modules loaded"

# Retrigger udev to set correct permissions (plugdev group) on new sysfs attributes
sleep 1
sudo udevadm trigger --subsystem-match=hid --action=add
sudo udevadm settle
echo "  → udev permissions applied"

# Restart daemon as the real user (sudo runs as root, so --user would target root's session)
REAL_USER="${SUDO_USER:-$USER}"
if [ -n "$REAL_USER" ] && [ "$REAL_USER" != "root" ]; then
    REAL_UID=$(id -u "$REAL_USER")
    sudo -u "$REAL_USER" XDG_RUNTIME_DIR="/run/user/$REAL_UID" systemctl --user restart openrazer-daemon.service
else
    systemctl --user restart openrazer-daemon.service
fi
sleep 2
echo "  → Daemon started"

# Quick verification
echo
echo "--- Verification ---"
echo "DKMS status:"
sudo dkms status -m "$DKMS_NAME" 2>/dev/null | head -5
echo
echo "Loaded modules:"
lsmod | grep -i razer || echo "  (none)"
echo
echo "Daemon status:"
systemctl --user is-active openrazer-daemon.service || true
echo

echo "============================================================"
echo "🎉 OpenRazer PR #2817 installed successfully!"
echo ""
echo "Your Razer Mouse Dock Pro should now detect the paired mouse."
echo "Open Polychromatic to check — the dock and mouse should"
echo "appear as separate entries."
echo ""
echo "To rollback to stock OpenRazer ${DKMS_OLD_VER}:"
echo "  sudo bash $0 rollback"
echo "============================================================"
