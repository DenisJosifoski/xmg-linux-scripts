# Fedora KDE Setup Toolkit (XMG Pro 16 VE M25 & DaVinci Resolve)

![OS - Fedora](https://img.shields.io/badge/OS-Fedora%2044%20KDE-blue?logo=fedora)
![Hardware - XMG](https://img.shields.io/badge/Hardware-XMG%20Pro%2016-red)
![License - GPLv3](https://img.shields.io/badge/License-GPLv3-green)

An all-in-one setup and maintenance toolkit for running **Fedora KDE** on the **XMG Pro 16 VE M25** laptop (and compatible Clevo/Uniwill chassis with hybrid NVIDIA/Intel graphics), plus automated fixers for **DaVinci Resolve Studio**, **Google Antigravity IDE**, and **Razer peripherals**.

---

## ⚡ Quick Start (The Easiest Way)

You do **not** need to manually download or run individual scripts one by one. This repository includes an interactive master control menu:

```bash
# 1. Clone or download this repository
git clone https://github.com/DenisJosifoski/xmg-linux-scripts.git
cd xmg-linux-scripts

# 2. Launch the interactive master menu
./setup.sh
```

```text
==================================================================
     Fedora KDE & XMG M25 Setup Toolkit (Master Menu)            
==================================================================
  [Core Laptop & Hardware]
   1) XMG M25 Drivers & TCC Patch             (fedora-xmg-m25.sh)
   2) Sleep & S2idle Battery Drain Fixes      (apply_fixes.sh)
   3) Install Keyboard Backlight Resume Hook  (xmg-backlight-resume.sh)

  [Applications & Workarounds]
   4) DaVinci Resolve Studio Full Installer   (fedora-resolve-installer.sh)
   5) DaVinci Resolve GPU & KDE Titlebar Fix  (fedora-resolve-fix.sh)
   6) Transcode Video Audio (AAC → PCM)       (prepare-for-resolve.sh)
   7) Antigravity IDE Exit Crash Fixer        (fedora-antigravity-fix.sh)

  [Razer Peripherals (Optional)]
   8) OpenRazer Mouse Dock Pro Driver         (fedora-openrazer.sh)
   9) Razer USB Autosuspend / PowerTOP Fix    (fix-razer-autosuspend.sh)

  [Automated Workflows]
   G) Guided Setup Wizard (interactive step-by-step)
   A) Apply Recommended Core Laptop Fixes (1 + 2)
   Q) Quit
------------------------------------------------------------------
```

> **Beginner Tip:** If you're not sure what you need, choose option **`G` (Guided Setup Wizard)**. It will ask you simple Yes/No questions and configure only what matches your hardware!

---

## 🖥️ Tested Environment

* **Laptop Model:** Schenker / XMG Pro 16 VE M25
* **Operating System:** Fedora 44 KDE (Linux 64-bit)
* **Kernel:** `7.0.x` (tested on `7.0.11` and `7.0.12`)
* **Display Server:** Wayland with KDE Plasma 6
* **GPU:** NVIDIA GeForce RTX 5070 Ti Laptop GPU + Intel Integrated Graphics (Hybrid PRIME)
* **DaVinci Resolve Studio:** `21.x` (Linux)

---

## 📋 Prerequisites / Before You Run

If you are setting up a fresh Fedora installation, complete these 4 simple steps first. They ensure your graphics card and system libraries are ready.

### Step A — Install NVIDIA Drivers

Fedora needs the official NVIDIA proprietary drivers to use your dedicated graphics card:

```bash
# 1. Enable RPM Fusion repositories (Free & Non-Free)
sudo dnf install -y \
  https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
  https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

# 2. Install NVIDIA driver and CUDA compute support
sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda

# 3. Wait for the background compiler to finish (~2-3 minutes), then verify:
modinfo -F version nvidia
# If a version number appears (e.g. 570.xx), the driver is ready — reboot!
# If blank, wait 1 more minute and re-test before rebooting.
sudo reboot
```

After rebooting, confirm NVIDIA is working:
```bash
nvidia-smi
```

---

### Step B — Enable NVIDIA for Wayland & KDE Plasma

To make sure KDE Plasma Wayland uses your NVIDIA card smoothly for display output:

```bash
sudo grubby --update-kernel=ALL --args="nvidia-drm.modeset=1"
sudo reboot
```

After reboot, verify:
```bash
glxinfo | grep "OpenGL renderer"
# Should display your NVIDIA GeForce RTX GPU (not llvmpipe)
```

---

### Step C — Install TUXEDO Control Center (TCC)

TUXEDO Control Center lets you manage fan profiles, keyboard backlights, and power modes. Install it from the official TUXEDO repository:

```bash
# 1. Add TUXEDO repository
sudo dnf config-manager addrepo --from-repofile="https://rpm.tuxedocomputers.com/fedora/tuxedo.repo"

# 2. Import their security key
sudo rpm --import https://rpm.tuxedocomputers.com/fedora/43/0x54840598.pub.asc

# 3. Install the Control Center app
sudo dnf install -y tuxedo-control-center
```

> **Note:** The RPM package installs default tuxedo drivers. Our toolkit (`fedora-xmg-m25.sh`) will replace them with custom Schenker-whitelisted drivers so your XMG hardware is recognized.

---

### Step D — Install Media Codecs

Fedora excludes certain audio/video codecs out of the box due to licensing. Install them so web videos, media players, and video editors play smoothly:

```bash
# 1. Swap limited ffmpeg for full-featured ffmpeg
sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing

# 2. Install multimedia plugins (H.264, H.265, AAC, etc.)
sudo dnf update -y @multimedia --setopt="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin
sudo dnf group install -y sound-and-video

# 3. Enable hardware video decoding for Intel iGPU
sudo dnf swap -y mesa-va-drivers mesa-va-drivers-freeworld
```

---

## 🗺️ How the Toolkit Works

```text
[Fresh Fedora Install]
    │
    ├── Step A: Install NVIDIA Drivers (RPM Fusion akmod-nvidia)
    ├── Step B: Enable Wayland Modeset (nvidia-drm.modeset=1)
    ├── Step C: Install TUXEDO Control Center (official repo)
    └── Step D: Install Full Media Codecs (ffmpeg & GStreamer)
    │
    ▼ [Reboot]
┌────────────────────────────────────────────────────────┐
│                      ./setup.sh                        │
│            (Interactive Master Control Menu)           │
└────────────────────────────────────────────────────────┘
    ├── [Option 1] fedora-xmg-m25.sh
    │     ├── Schenker DMI whitelist bypass
    │     ├── M25 TDP power limit tuning
    │     └── Wayland / Electron crash patches for TCC
    │
    ├── [Option 2] apply_fixes.sh
    │     ├── Fixes S2idle battery drain during sleep
    │     ├── Enables NVIDIA S0ix dynamic power saving
    │     └── Fixes Wayland lock-screen freeze (nvidia-drm.fbdev=1)
    │
    ├── [Option 3] xmg-backlight-resume.sh
    │     └── Sleep hook to restore RGB backlight profiles on resume
    │
    ├── [Option 4 / 5] DaVinci Resolve Studio Tools
    │     ├── fedora-resolve-installer.sh (Automated 1-Click GUI Installer)
    │     ├── fedora-resolve-fix.sh (NVIDIA PRIME & KDE Titlebar Fixer)
    │     └── resolve-launch.sh (Reference launch script)
    │
    ├── [Option 6] prepare-for-resolve.sh
    │     └── Lossless AAC → PCM audio transcoder with Dolphin context menu
    │
    ├── [Option 7] fedora-antigravity-fix.sh
    │     └── Replaces buggy @parcel/watcher node module to fix 90°C CPU exit spike
    │
    └── [Option 8 / 9] Razer Peripherals (Optional)
          ├── fedora-openrazer.sh (Mouse Dock Pro relay driver with rollback)
          └── fix-razer-autosuspend.sh (Stops mouse & USB hub dropouts)
```

---

## 🛠️ Detailed Script Guide

Every script can either be run through `./setup.sh` or executed individually:

### 1. Laptop Hardware & Power

#### `fedora-xmg-m25.sh` — XMG Drivers & TCC Patch
* **What it does:** Downloads official Tuxedo drivers and applies 4 critical source patches:
  1. **Schenker DMI Whitelist:** Allows the driver to recognize Schenker / XMG motherboard IDs (`X6PR5xxW_X6RP5xxW`).
  2. **LED Collision Patch:** Disables conflicting ACPI LED registrations that crash `tccd` on newer Linux kernels.
  3. **M25 TDP Limits:** Tunes power limit profiles specifically for the M25 chassis.
  4. **GCC 14 Pointer Fix:** Resolves strict pointer compilation errors on newer GCC toolchains.
* **Standalone Run:**
  ```bash
  sudo bash fedora-xmg-m25.sh
  ```

#### `apply_fixes.sh` — S2idle Sleep & Battery Drain Fix
* **The Problem:** Modern Linux laptops use `s2idle` (Modern Standby). Without proper tuning, NVIDIA GPUs and rogue ACPI devices keep waking up the CPU, draining your battery inside your backpack and causing the laptop to run hot while sleeping.
* **What it does:**
  * Configures NVIDIA Dynamic Power Management (`0x02`) and S0ix sleep states.
  * Adds `nvidia-drm.fbdev=1` to kernel parameters to prevent screen freezing on wake.
  * Creates an automated systemd service (`disable-acpi-wakeups.service`) and sleep hook to disable rogue ACPI wakeup lines (`XHCI`, `PEG*`, `RP*`).
  * Rebuilds initramfs with `dracut -f` and updates SELinux contexts.
* **Standalone Run:**
  ```bash
  sudo bash apply_fixes.sh
  ```

#### `xmg-backlight-resume.sh` — Keyboard Backlight Resume Hook
* **What it does:** A systemd-sleep hook placed in `/usr/lib/systemd/system-sleep/` that waits 5 seconds after waking from sleep, queries active user sessions, and re-applies custom RGB backlight profiles via Python.
* **Standalone Setup:**
  ```bash
  sudo cp xmg-backlight-resume.sh /usr/lib/systemd/system-sleep/
  sudo chmod +x /usr/lib/systemd/system-sleep/xmg-backlight-resume.sh
  ```

---

### 2. DaVinci Resolve Studio

#### `fedora-resolve-installer.sh` — Automated 1-Click Installer
* **What it does:**
  1. Shows an animated progress bar while extracting `DaVinci_Resolve_Studio_*_Linux.zip`.
  2. Automatically installs required legacy system dependencies (`libxcrypt-compat`).
  3. Runs Blackmagic's installer with `SKIP_PACKAGE_CHECK=1` to bypass unsupported distro warnings.
  4. Automatically runs `fedora-resolve-fix.sh` after installation.
  5. Cleans up the temporary `.run` file when finished.
* **Requirements:** Place the downloaded `DaVinci_Resolve_Studio_*_Linux.zip` in the same directory.
* **Standalone Run:**
  ```bash
  bash fedora-resolve-installer.sh
  ```

#### `fedora-resolve-fix.sh` — GPU, Audio & Window Fixer
* **What it does:**
  * **Fixes crashes on Fedora:** Moves conflicting bundled system libraries (`libglib-2.0`, `libgio-2.0`, etc.) to a disabled backup directory so Resolve uses Fedora's system libraries.
  * **Configures NVIDIA PRIME:** Ensures the desktop shortcuts and terminal launchers run Resolve on the discrete NVIDIA GPU.
  * **KDE Window Title Bar Rule:** DaVinci Resolve requests borderless mode by default on KDE. This script automatically adds a KWin window rule to force standard title bars and minimize/maximize buttons.
* **Standalone Run:**
  ```bash
  bash fedora-resolve-fix.sh
  ```

#### `prepare-for-resolve.sh` — Lossless AAC → PCM Audio Transcoder
* **The Problem:** DaVinci Resolve on Linux has limited native support for AAC audio streams in MP4/MOV containers.
* **What it does:** Instantly remuxes audio from AAC to uncompressed 16-bit PCM (`pcm_s16le`) while copying the video stream **100% untouched and losslessly** (takes just seconds per gigabyte).
  * Supports `.mp4`, `.mov`, `.mkv`, `.m4v`, `.avi`, `.webm`, `.ts`.
  * Outputs `${filename}_resolve.mov` (original files are never modified or overwritten).
  * Integrates with KDE Dolphin context menus (right-click → Convert) and sends desktop notifications via `notify-send`.
* **Standalone Run:**
  ```bash
  # Convert all videos in the current folder:
  ./prepare-for-resolve.sh

  # Or convert a specific folder or file:
  ./prepare-for-resolve.sh /path/to/videos
  ```

---

### 3. Developer Tools

#### `fedora-antigravity-fix.sh` — IDE Exit Crash & CPU Spike Fixer
* **The Problem:** Google Antigravity IDE bundles `@parcel/watcher` v2.5.1, which has a known teardown race condition on Linux. When closing the IDE, it triggers a background `SIGSEGV` crash that causes `systemd-coredump` to write multi-gigabyte coredumps to disk, pegging the CPU at 100% and spiking temperatures past 90°C.
* **What it does:** Surgically replaces the buggy native Node module with stable `@parcel/watcher` v2.5.6 from NPM, installs desktop shortcuts, and eliminates the exit crash entirely.
* **Standalone Run:**
  ```bash
  sudo bash fedora-antigravity-fix.sh
  ```

---

### 4. Razer Peripherals (Optional)

#### `fedora-openrazer.sh` — Mouse Dock Pro Relay Driver (PR #2817)
* **What it does:** For owners of the **Razer Mouse Dock Pro** and compatible wireless mice (Basilisk V3 Pro, Cobra Pro, Naga V2 Pro). Clones and installs the experimental PR #2817 branch with full mouse-to-dock pass-through relay support.
* **Includes Rollback:** Automatically creates backups and allows 1-command rollback:
  ```bash
  # Install PR #2817 driver:
  bash fedora-openrazer.sh install

  # Restore official OpenRazer 3.12.4:
  bash fedora-openrazer.sh rollback
  ```

#### `fix-razer-autosuspend.sh` — USB Autosuspend & PowerTOP Fix
* **What it does:** Configures `/etc/udev/rules.d/99-usb-power.rules` to prevent Linux USB autosuspend from putting the Razer Basilisk V3 Pro (`1532:00ab`) or its internal USB hub (`05e3:0610`) to sleep, preventing mouse lag and disconnects. Also updates `powertop-tuning.service` if present.
* **Standalone Run:**
  ```bash
  sudo bash fix-razer-autosuspend.sh
  ```

---

## ❓ Frequently Asked Questions (FAQ)

### What happens after a kernel update (`dnf upgrade`)?
Because `fedora-xmg-m25.sh` and `fedora-openrazer.sh` install through **DKMS (Dynamic Kernel Module Support)**, your drivers are **automatically recompiled** for new kernels in the background. You do not need to re-run the scripts after normal updates.

### What if a DNF package update overwrites the Tuxedo driver?
If `tuxedo-drivers` gets updated directly from the Tuxedo repository during a system upgrade, simply launch `./setup.sh` and select option **1** (`fedora-xmg-m25.sh`). The script will re-apply the custom Schenker DMI patches cleanly.

### Can I run only one specific script?
**Yes!** Every script in this repository is completely independent. If you only want the DaVinci Resolve fix, simply run `fedora-resolve-fix.sh`. If you only want the Antigravity fix, run `fedora-antigravity-fix.sh`.

---

## 🛡️ Disclaimer & License

These scripts are provided in good faith to assist Linux laptop users. Always back up your important data. 

Released under the **GNU General Public License v3 (GPLv3)**. You are free to inspect, modify, and distribute this software under the same license terms.
