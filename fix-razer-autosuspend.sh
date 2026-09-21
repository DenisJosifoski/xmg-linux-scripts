#!/usr/bin/env bash
set -euo pipefail

# Ensure script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run this script with sudo:"
  echo "  sudo bash $0"
  exit 1
fi

echo "==> Configuring udev rule for Razer Basilisk V3 Pro and internal USB hub..."

cat << 'RULE' > /etc/udev/rules.d/99-usb-power.rules
# Razer Basilisk V3 Pro & internal hub - completely disable autosuspend
ACTION!="remove", SUBSYSTEM=="usb", ATTR{idVendor}=="1532", ATTR{idProduct}=="00ab", ENV{ID_AUTOSUSPEND}="0", ATTR{power/control}="on"
ACTION!="remove", SUBSYSTEM=="usb", ATTR{idVendor}=="05e3", ATTR{idProduct}=="0610", ENV{ID_AUTOSUSPEND}="0", ATTR{power/control}="on"
RULE

echo "==> Reloading and triggering udev rules..."
udevadm control --reload-rules
udevadm trigger --subsystem-match=usb

# Fix powertop-tuning.service if present so it doesn't overwrite USB power states on boot
if [ -f /etc/systemd/system/powertop-tuning.service ]; then
  echo "==> Updating powertop-tuning.service to preserve Razer USB power state..."
  cat << 'SERVICE' > /etc/systemd/system/powertop-tuning.service
[Unit]
Description=PowerTOP power saving tunables
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c '\
  echo 1500 > /proc/sys/vm/dirty_writeback_centisecs; \
  echo 1 > /sys/module/snd_hda_intel/parameters/power_save; \
  echo Y > /sys/module/snd_hda_intel/parameters/power_save_controller; \
  echo 0 > /proc/sys/kernel/nmi_watchdog; \
  for dev in /sys/bus/pci/devices/*/power/control; do echo auto > $dev; done; \
  for dev in /sys/bus/usb/devices/*; do \
    [ -f "$dev/power/control" ] || continue; \
    vendor=$(cat "$dev/idVendor" 2>/dev/null || true); \
    product=$(cat "$dev/idProduct" 2>/dev/null || true); \
    if [ "$vendor" = "1532" ] || [ "$vendor" = "05e3" -a "$product" = "0610" ]; then \
      echo on > "$dev/power/control"; \
    else \
      echo auto > "$dev/power/control"; \
    fi; \
  done'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SERVICE
  systemctl daemon-reload
fi

echo "==> Applying live power control settings..."
# Apply directly to currently attached matching devices
for dev in /sys/bus/usb/devices/*; do
  if [ -f "$dev/idVendor" ] && [ -f "$dev/idProduct" ]; then
    vendor=$(cat "$dev/idVendor" 2>/dev/null || true)
    product=$(cat "$dev/idProduct" 2>/dev/null || true)
    
    # Razer Basilisk V3 Pro (1532:00ab) or Genesys Logic Hub (05e3:0610)
    if { [ "$vendor" = "1532" ] && [ "$product" = "00ab" ]; } || \
       { [ "$vendor" = "05e3" ] && [ "$product" = "0610" ]; }; then
      if [ -f "$dev/power/control" ]; then
        echo "on" > "$dev/power/control"
        echo "    Set $dev ($vendor:$product) power/control -> on"
      fi
    fi
  fi
done

echo ""
echo "==> Current Status of Razer and Hub Power Control:"
for dev in /sys/bus/usb/devices/*; do
  if [ -f "$dev/idVendor" ] && [ -f "$dev/idProduct" ]; then
    vendor=$(cat "$dev/idVendor" 2>/dev/null || true)
    product=$(cat "$dev/idProduct" 2>/dev/null || true)
    if { [ "$vendor" = "1532" ] && [ "$product" = "00ab" ]; } || \
       { [ "$vendor" = "05e3" ] && [ "$product" = "0610" ]; }; then
      ctrl=$(cat "$dev/power/control" 2>/dev/null || echo "N/A")
      echo "  Device $(basename "$dev") [$vendor:$product]: power/control = $ctrl"
    fi
  fi
done

echo ""
echo "Configuration successfully applied!"
