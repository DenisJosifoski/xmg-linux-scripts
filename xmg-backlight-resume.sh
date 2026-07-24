#!/bin/sh
# System sleep hook to restore XMG backlight on resume
echo "$(date): Hook called with \$1=$1, \$2=$2" >> /tmp/xmg-backlight-debug.log
case "$1/$2" in
  post/*)
    # Give the USB device/driver a moment to initialize after wake
    sleep 5
    
    # Find active non-root users and restore their backlight profiles
    for u in $(loginctl list-sessions --no-legend 2>/dev/null | awk '{print $3}' | sort -u); do
      echo "$(date): Processing user $u" >> /tmp/xmg-backlight-debug.log
      if [ "$u" != "root" ] && [ -d "/home/$u" ]; then
        if [ -f "/home/$u/.config/backlight-linux/profile.json" ]; then
          echo "$(date): Restoring profile for $u..." >> /tmp/xmg-backlight-debug.log
          runuser -u "$u" -- /usr/local/lib/xmg-backlight-venv/bin/python -m xmg_backlight.restore_profile >> /tmp/xmg-backlight-debug.log 2>&1
          echo "$(date): Restore command exited with code $?" >> /tmp/xmg-backlight-debug.log
        else
          echo "$(date): Profile file not found for user $u" >> /tmp/xmg-backlight-debug.log
        fi
      fi
    done
    ;;
esac
