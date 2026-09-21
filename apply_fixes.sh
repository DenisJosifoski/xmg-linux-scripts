#!/bin/bash
# ==============================================================================
# XMG Laptop - Battery Drain & S2idle Sleep Fix
# ==============================================================================

if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run this script with sudo: sudo bash $0"
  exit 1
fi

echo "========================================="
echo "Applying XMG / NVIDIA S2idle Sleep Fixes"
echo "========================================="

# 1. NVIDIA S0ix & Dynamic Power Management Configuration
echo "[1/4] Configuring NVIDIA Power Management..."
mkdir -p /etc/modprobe.d/
cat << 'EOF' > /etc/modprobe.d/nvidia-power.conf
options nvidia NVreg_DynamicPowerManagement=0x02
options nvidia NVreg_EnableS0ixPowerManagement=1
options nvidia NVreg_PreserveVideoMemoryAllocations=1
options nvidia NVreg_TemporaryFilePath=/var/tmp
EOF

# Enable NVIDIA suspend/resume systemd services
systemctl enable nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service 2>/dev/null || true

# Add fbdev=1 to kernel cmdline for Wayland lock screen freeze fix
echo "[+] Adding nvidia-drm.fbdev=1 to kernel parameters..."
if command -v grubby &>/dev/null; then
    grubby --update-kernel=ALL --args="nvidia-drm.fbdev=1"
fi

# 2. ACPI Wakeup Disabler Script & Systemd Boot Service
echo "[2/4] Setting up ACPI Wakeup Disabler service..."
cat << 'EOF' > /usr/local/bin/disable-acpi-wakeups.sh
#!/bin/bash
# Disable rogue ACPI wakeup devices that prevent deep CPU/PCIe C-states during s2idle
DEVICES="XHCI PEG1 PEG2 RP09 RP15 RP21 RP23 RP25"
for dev in $DEVICES; do
    if grep -q "^$dev.*\*enabled" /proc/acpi/wakeup 2>/dev/null; then
        echo "$dev" > /proc/acpi/wakeup
    fi
done
EOF
chmod +x /usr/local/bin/disable-acpi-wakeups.sh

# Create systemd service to run at boot and before sleep
cat << 'EOF' > /etc/systemd/system/disable-acpi-wakeups.service
[Unit]
Description=Disable ACPI Wakeup Devices for Low Power Sleep
After=multi-user.target
Before=sleep.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/disable-acpi-wakeups.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target sleep.target
EOF

systemctl daemon-reload
systemctl enable disable-acpi-wakeups.service
systemctl restart disable-acpi-wakeups.service

# 3. System-sleep hook with correct SELinux context
echo "[3/4] Setting up systemd-sleep hook..."
mkdir -p /usr/lib/systemd/system-sleep/
cat << 'EOF' > /usr/lib/systemd/system-sleep/disable-wakeups.sh
#!/bin/bash
case "$1" in
    pre)
        /usr/local/bin/disable-acpi-wakeups.sh
        ;;
    post)
        ;;
esac
EOF
chmod +x /usr/lib/systemd/system-sleep/disable-wakeups.sh

# Clean up legacy /etc/systemd/system-sleep/disable-wakeups.sh if present
rm -f /etc/systemd/system-sleep/disable-wakeups.sh

# Fix SELinux file contexts
if command -v restorecon &>/dev/null; then
    restorecon -v /usr/local/bin/disable-acpi-wakeups.sh /usr/lib/systemd/system-sleep/disable-wakeups.sh /etc/systemd/system/disable-acpi-wakeups.service 2>/dev/null || true
fi

# 4. Rebuilding initramfs with dracut
echo "[4/4] Updating initramfs with Dracut (this may take ~30 seconds)..."
dracut -f

echo "========================================="
echo "Fixes applied successfully!"
echo "Please reboot your laptop for the new NVIDIA S0ix parameters to take effect."
echo "========================================="
