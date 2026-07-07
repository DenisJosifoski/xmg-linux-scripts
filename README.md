# Fedora KDE Setup Scripts (XMG Pro 16 VE M25 & DaVinci Resolve)

![OS - Fedora](https://img.shields.io/badge/OS-Fedora%2044%20KDE-blue?logo=fedora)
![Hardware - XMG](https://img.shields.io/badge/Hardware-XMG%20Pro%2016-red)
![License - GPLv3](https://img.shields.io/badge/License-GPLv3-green)

Tuxedo driver DKMS patch + DaVinci Resolve Studio installer/fixer for XMG Pro 16 VE M25 on Fedora KDE (hybrid NVIDIA/Intel).

---

## Tested Environment
* **OS:** Fedora 44 KDE
* **Kernel:** `7.0.x` (tested on `7.0.11` and `7.0.12`)
* **DaVinci Resolve Studio:** `21.x` (Linux)
* **GPU:** NVIDIA GeForce RTX 5070 Ti Laptop GPU + Intel integrated graphics (hybrid PRIME offload)
* **Laptop Model:** Schenker / XMG Pro 16 VE M25

---

## Prerequisites / Before You Run

### Step A — Install NVIDIA Drivers (Required First)

The `fedora-xmg-m25.sh` script detects your installed NVIDIA driver version to decide how to patch TCC's Electron flags. You must install NVIDIA drivers **before** running it. Without them, GPU-aware patching cannot apply correctly.

The recommended method on Fedora is via RPM Fusion:

```bash
# 1. Enable RPM Fusion (free + nonfree)
sudo dnf install -y \
  https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
  https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

# 2. Install driver and CUDA support
sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda

# 3. Wait for the akmod background build to complete (~2-3 min), then verify:
modinfo -F version nvidia
# If a version number is returned, the module is built and ready — reboot.
# If nothing is returned, wait another minute and check again before rebooting.
sudo reboot
```

> **RTX 4000/5000 series note:** On Fedora 44 with current `akmod-nvidia`, open kernel module support for Turing+ GPUs is enabled automatically — no extra macro step needed. If you do land in a broken state after reboot (no display / wrong resolution), you can manually set it and force a rebuild:
> ```bash
> sudo sh -c 'echo "%_with_kmod_nvidia_open 1" > /etc/rpm/macros.nvidia-kmod'
> sudo akmods --force && sudo reboot
> ```

> **Secure Boot note:** The locally-built akmod module is unsigned by default. Disable Secure Boot in BIOS/UEFI before installing, or follow a module-signing guide if you need Secure Boot enabled.

After reboot, verify the driver is active:

```bash
nvidia-smi
# Should show your GPU and driver version
```

---

### Step B — Enable NVIDIA for Wayland (Required for KDE Plasma)

Even after a successful driver install, `nvidia-drm.modeset=1` must be passed to the kernel for NVIDIA to properly own the display on Wayland. Without it, screen sharing, hardware video encode/decode (NVENC/NVDEC), and TCC GPU profile switching may behave incorrectly. `nvidia-smi` working does not mean this is already set — it only confirms the driver is loaded for compute, not that the display stack is using it.

```bash
sudo grubby --update-kernel=ALL --args="nvidia-drm.modeset=1"
sudo reboot
```

After reboot, verify it applied:

```bash
# Check it's in the kernel command line
cat /proc/cmdline | grep nvidia

# Confirm Wayland is using the NVIDIA driver, not software rendering
glxinfo | grep "OpenGL renderer"
# Should show RTX 5070 Ti, not llvmpipe or softpipe
```

---

### Step C — Install TUXEDO Control Center (Required Before Driver Script)

The `fedora-xmg-m25.sh` script patches the TCC `.desktop` launcher files with GPU-aware Electron flags. For this to work, TCC must already be installed so the `.desktop` files exist on disk. Install it via the official TUXEDO repository:

```bash
# 1. Add the official TUXEDO RPM repository
sudo dnf config-manager addrepo \
  --from-repofile="https://rpm.tuxedocomputers.com/fedora/tuxedo.repo"

# 2. Import the TUXEDO GPG key
sudo rpm --import https://rpm.tuxedocomputers.com/fedora/43/0x54840598.pub.asc

# 3. Install TCC (tuxedo-drivers is pulled in automatically as a dependency,
#    but our script will replace it with a patched version in the next step)
sudo dnf install -y tuxedo-control-center
```

> **Note:** The `tuxedo-drivers` package installed as a dependency above will be replaced by the custom-patched version built by `fedora-xmg-m25.sh`. This is intentional — the RPM version lacks the Schenker DMI whitelist bypass and custom M25 TDP limits.

> **Do not run `fedora-xmg-m25.sh` yet.** Complete Steps A, B, C, and D first, then reboot before proceeding.

---

### Step D — Install Media Codecs

Fedora ships without proprietary multimedia codecs for legal reasons. This step installs full codec support via RPM Fusion — required for correct browser video playback, hardware video decode, and DaVinci Resolve's media engine.

> **Note:** RPM Fusion must already be enabled (done in Step A). Run these in the same session, before the reboot.

```bash
# 1. Swap Fedora's codec-limited ffmpeg-free for the full RPM Fusion build
sudo dnf swap ffmpeg-free ffmpeg --allowerasing

# 2. Install GStreamer multimedia plugins (h264, h265, aac, mp3, and more)
sudo dnf update @multimedia --setopt="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin

# 3. Install sound and video complementary packages
sudo dnf group install sound-and-video

# 4. Swap Mesa VA-API drivers for freeworld build
#    Enables H.264/H.265 hardware decoding on the Intel iGPU side of your hybrid setup
#    Not needed for the NVIDIA dGPU (handled by the NVIDIA driver directly)
sudo dnf swap mesa-va-drivers mesa-va-drivers-freeworld
```

After the reboot in Step B, verify hardware acceleration is working:

```bash
# Confirm NVIDIA hardware decode paths are available
ffmpeg -hwaccels
# Should include: cuda, nvdec

# Confirm Intel iGPU VA-API is working (hybrid graphics)
vainfo
# Should list VAProfileH264 and VAProfileHEVC entries
```

---

### General Prerequisites
* **Operating System:** Fedora KDE Spin (specifically using SDDM, KDE Plasma, and Wayland).
* **Network:** Active internet connection is required to fetch driver dependencies and clone repositories.
* **Privileges:** `sudo` access is required for installing dependencies, copying kernel modules, and patching system-level desktop shortcuts.
* **For DaVinci Resolve:** You must manually download the official **DaVinci Resolve Studio (Linux)** `.zip` installer from [blackmagicdesign.com](https://www.blackmagicdesign.com/products/davinciresolve) before running the install script. Place the `.zip` in the same directory as `fedora-resolve-installer.sh`.

---

## How the Scripts Relate to Each Other

```
[Step A] Install NVIDIA Drivers (RPM Fusion akmod-nvidia)
[Step B] Enable NVIDIA for Wayland (nvidia-drm.modeset=1 + reboot)
[Step C] Install TUXEDO Control Center (official TUXEDO repo)
[Step D] Install Media Codecs (ffmpeg swap + GStreamer + Mesa freeworld)
[Reboot]
    │
fedora-xmg-m25.sh (Run this after Steps A, B & C)
    └── Replaces stock tuxedo-drivers with custom-patched DKMS build
    └── Applies Schenker DMI whitelist + M25 TDP limits + GCC 14 fixes
    └── Patches TCC .desktop shortcuts with GPU-aware Electron flags
[Reboot]
    │
Download DaVinci Resolve Studio .zip from blackmagicdesign.com
    │
fedora-resolve-installer.sh
    └── Installs system dependencies (like libxcrypt-compat) first
    └── Unzips and executes Blackmagic .run GUI installer
    └── Triggers fedora-resolve-fix.sh automatically
          ├── Moves conflicting Fedora system glib/gio libraries to /opt/resolve/libs/disabled-libraries/
          ├── Patches system application .desktop shortcuts with NVIDIA PRIME flags
          ├── Generates ~/resolve-launch.sh in your home directory (KDE appmenu workaround)
          └── Configures KWin window rule to force window decoration/title bar on KDE Plasma

fedora-antigravity-fix.sh (1-Click Installer & Fixer)
    └── Automatically downloads and installs Antigravity IDE (if not present)
    └── Surgically swaps unstable @parcel/watcher v2.5.1 with stable v2.5.6 C++ node module
    └── Prevents massive coredumps, high CPU usage, and 90°C+ heat spikes on exit
    └── Registers system-wide and user desktop shortcuts
```

---

## 1. Hardware & Driver Control

### `fedora-xmg-m25.sh` (Tuxedo Drivers + Schenker DMI Patch)
A master installation script that pulls the latest `tuxedo-drivers` from Tuxedo's GitLab, patches them for compatibility, builds the modules using DKMS, and patches the Tuxedo Control Center (TCC) application to prevent crashes under Wayland.

> **Run Steps A, B, C, and D from the Prerequisites section before this script.**

* **What it does under the hood:**
  * Installs compilation dependencies: `git`, `dkms`, `make`, `gcc`, `fedora-repos-archive`, `python3`, and matching `kernel-devel`/`kernel-headers` packages.
  * Applies **four source patches**:
    1. *Intel Atom Header Fix:* Replaces `INTEL_ATOM_AIRMONT_MID` with `INTEL_ATOM_AIRMONT_NP` to maintain kernel compatibility.
    2. *GCC 14 Pointer Fix:* Removes strict pointer enforcement errors (`.owner = THIS_MODULE`) in `clevo_acpi.c`.
    3. *Schenker DMI Whitelist Bypass:* Automatically whitelists the Schenker board model (`X6PR5xxW_X6RP5xxW`) to allow Tuxedo drivers to run on XMG systems.
    4. *Clevo LEDs Conflict Patch:* Disables redundant ACPI-based LED registration in `tuxedo_keyboard` for the `X6PR5xxW_X6RP5xxW` board, preventing name collisions with the `ite_8291` per-key RGB driver that cause `tccd` crashes on newer kernels.
  * Adjusts power limit configuration (TDP limits) specific to the M25 chassis.
  * Automatically configures and rebuilds 27 kernel modules in DKMS.
  * Patches the Tuxedo Control Center `.desktop` shortcuts to launch with GPU-aware Electron flags (`--ozone-platform-hint=auto` or `--disable-gpu`) depending on your NVIDIA driver version to ensure stability under Wayland.
* **Download & Run:**
  ```bash
  curl -L -o fedora-xmg-m25.sh https://raw.githubusercontent.com/DenisJosifoski/xmg-linux-scripts/main/fedora-xmg-m25.sh
  chmod +x fedora-xmg-m25.sh
  ./fedora-xmg-m25.sh
  ```
* **Updates & Kernel Upgrades:**
  * **Kernel Upgrades (`dnf upgrade`):** Because the drivers are registered through **DKMS**, they will automatically compile and install for new kernels whenever your system is updated. You do **not** need to re-run the script after normal kernel updates.
  * **Driver Updates:** Whenever Tuxedo releases a new driver update on GitLab, you can simply run `fedora-xmg-m25.sh` again. The script is fully idempotent and will automatically unregister the old version, pull the latest code from GitLab, re-apply your custom patches, and build/register the new version.
  * **Important:** Avoid installing or upgrading `tuxedo-drivers` packages directly via the TUXEDO RPM repository, as those packages will overwrite these custom-patched drivers and lack the Schenker DMI whitelist bypass and custom TDP limits.
  * **Fedora Major Version Upgrades:** These scripts were developed and tested on **Fedora 44**. After upgrading to a new Fedora major version (e.g. F44 → F45), re-run `fedora-xmg-m25.sh` to rebuild the drivers against the new kernel and verify TCC desktop patches are still in place.

---

## 2. DaVinci Resolve Studio Automation

### `fedora-resolve-installer.sh` (Automated Installer Wrapper)
Automates the entire DaVinci Resolve Studio installation process on Fedora. It extracts the installer, automatically installs system dependencies (like `libxcrypt-compat`), bypasses incompatible package checks (`SKIP_PACKAGE_CHECK=1`), executes the GUI installer, calls the fixer script, and performs post-install cleanup.

* **Requirements:** Place the downloaded DaVinci Resolve `.zip` installer in the same folder where you run this script.
* **Download & Run:**
  ```bash
  curl -L -o fedora-resolve-installer.sh https://raw.githubusercontent.com/DenisJosifoski/xmg-linux-scripts/main/fedora-resolve-installer.sh
  chmod +x fedora-resolve-installer.sh
  ./fedora-resolve-installer.sh
  ```

### `fedora-resolve-fix.sh` (Post-Install Fixer)
Solves library conflicts on Fedora (moves conflicting `glib` and `gio` libraries to a backup folder), updates desktop application shortcuts to launch Resolve using NVIDIA discrete graphics, and automatically configures a KWin Window Rule to force window decorations (title bar, frame) on KDE Plasma systems. This is triggered automatically by the installer script, but can be run independently if needed.

* **Download & Run:**
  ```bash
  curl -L -o fedora-resolve-fix.sh https://raw.githubusercontent.com/DenisJosifoski/xmg-linux-scripts/main/fedora-resolve-fix.sh
  chmod +x fedora-resolve-fix.sh
  ./fedora-resolve-fix.sh
  ```

### `resolve-launch.sh` (KDE Launch Helper - Reference Snapshot Only)
A helper script auto-generated by `fedora-resolve-fix.sh` and written directly to `~/resolve-launch.sh` in your home folder. It sets the correct NVIDIA PRIME environment variables and unloads/reloads the KDE global menu module (`appmenu`) to prevent keyboard lockouts when launching DaVinci Resolve 21 on KDE Wayland.

> **Note:** The copy in this repository is a reference snapshot only. Do not download it manually — it is generated automatically by the fixer script and tailored to your system.

* **How to use:** Keep this script in your home folder. If you launch Resolve from the desktop/applications menu, the patched shortcut runs it automatically. If you want to launch from the terminal, run `~/resolve-launch.sh`.

### `prepare-for-resolve.sh` (AAC-to-PCM Audio Transcoder)
A highly useful helper utility that scans the directory for `.mp4`, `.mov`, and `.mkv` files and remuxes their AAC audio to raw 24-bit PCM (`pcm_s24le`) while copying the video stream untouched.

* **Why it's needed:** DaVinci Resolve on Linux has native audio limitations (especially with AAC audio codec parsing on free/studio versions depending on packaging). Running this script allows you to quickly make your camera footage fully compatible with Resolve without re-rendering the video stream.
* **Prerequisites:** Requires `ffmpeg` installed on your system.
* **Download & Run:**
  ```bash
  curl -L -o prepare-for-resolve.sh https://raw.githubusercontent.com/DenisJosifoski/xmg-linux-scripts/main/prepare-for-resolve.sh
  chmod +x prepare-for-resolve.sh
  # Run it in any directory containing video files:
  ./prepare-for-resolve.sh
  ```
* **Native AAC Playback Alternative (DaVinci Resolve Studio only):** If you own the Studio version of Resolve and prefer native AAC playback/encoding inside the application without transcoding your media files, you can install the external [Resolve-Linux-Studio-AAC-FDK-Encoder-plugin](https://github.com/hexitnz/Resolve-Linux-Studio-AAC-FDK-Encoder-plugin).

---

## 3. Antigravity IDE Automation

### `fedora-antigravity-fix.sh` (Installer & Surgical Teardown Patch)
Surgically patches the Google Antigravity IDE on Fedora KDE to resolve a critical CPU spike and hardware stress (90°C+) occurring on application exit. 

* **Why it's needed:** The IDE bundles `@parcel/watcher` v2.5.1, which has a known teardown race condition on Linux, triggering a `SIGSEGV` crash in the background node service. This crash prompts `systemd-coredump` to compress and write a massive multi-gigabyte coredump on exit, causing extreme CPU usage and heating.
* **What it does under the hood:**
  * Detects a local Antigravity IDE installation tarball in `~/Downloads` or automatically fetches the latest stable release URL.
  * Installs the IDE to `/opt/antigravity-ide` if not already present.
  * Downloads stable `@parcel/watcher` v2.5.6 from NPM registry and swaps the native C++ node module (`watcher.node`) into the IDE's installation folder.
  * Registers system-wide and user desktop `.desktop` shortcuts.
* **Download & Run:**
  ```bash
  curl -L -o fedora-antigravity-fix.sh https://raw.githubusercontent.com/DenisJosifoski/xmg-linux-scripts/main/fedora-antigravity-fix.sh
  chmod +x fedora-antigravity-fix.sh
  sudo ./fedora-antigravity-fix.sh
  ```

---

## Troubleshooting

### 1. DKMS compilation/build fails during driver setup
* **Symptom:** The script exits with a compilation error, or the drivers fail to load after run.
* **Solution:** Ensure your kernel development packages match your running kernel. Run:
  ```bash
  sudo dnf install -y kernel-devel-$(uname -r) kernel-headers-$(uname -r)
  ```
  And then re-run the driver script.

### 2. DaVinci Resolve crashes immediately on launch / nothing happens
* **Symptom:** Clicking the DaVinci Resolve application shortcut flashes a loading cursor, then exits without opening a window.
* **Solution:** Run the generated launch script manually from a terminal to see the error output:
  ```bash
  bash ~/resolve-launch.sh
  ```
  * **Missing `libcrypt.so.1`:** If it says `error while loading shared libraries: libcrypt.so.1: cannot open shared object file`, ensure `libxcrypt-compat` is installed by running `sudo dnf install -y libxcrypt-compat`. (The updated `fedora-resolve-installer.sh` now installs this automatically).
  * **Glib/Gio Conflicts:** If it outputs symbol lookup errors related to `glib` or `gio`, verify that `fedora-resolve-fix.sh` successfully moved those libraries out of `/opt/resolve/libs/` to `/opt/resolve/libs/disabled-libraries/`.

### 6. DaVinci Resolve is missing the title bar / window controls
* **Symptom:** DaVinci Resolve opens, but has no title bar or borders, making it impossible to minimize, maximize, or close using window controls.
* **Solution:** On KDE Plasma, DaVinci Resolve requests KWin to hide borders. The fixer script `fedora-resolve-fix.sh` automatically configures a KWin Window Rule to override this. If you are experiencing this:
  1. Confirm the rule is in place (or re-run `fedora-resolve-fix.sh`).
  2. Alternatively, open **System Settings > Window Management > Window Rules**, find the rule for DaVinci Resolve, and ensure **No titlebar and frame** is set to **Force -> No**.

### 3. Tuxedo Control Center fails to open or crashes on Wayland
* **Symptom:** TCC starts in the background but the interface won't load or displays a blank window.
* **Solution:** The script patches the `.desktop` launchers with Wayland/Electron compatibility flags. Verify if the flags are set correctly by running it from the CLI:
  ```bash
  tuxedo-control-center --ozone-platform-hint=auto --disable-gpu
  ```
  *(Note: The `--disable-gpu` flag is applied automatically by the installer script depending on its NVIDIA driver version detection, which requires driver version ≥ 545 for hardware acceleration. The manual CLI command above is strictly for testing and verification purposes.)*

  If it loads successfully with `--disable-gpu`, check that the patched `.desktop` file matches this configuration.

* **Symptom: TCC won't open and logs "dbusController: init failed => DBusError: The name is not activatable"**
  * **Cause:** The `tccd` background daemon crashed because of an `ENOENT` error looking for the `/sys/class/leds/rgb:kbd_backlight/multi_intensity` file. This happens on newer kernels when `tuxedo_keyboard` and `ite_8291` conflict over the `rgb:kbd_backlight` LED name, causing all per-key LEDs to get renamed to `rgb:kbd_backlight_1` to `rgb:kbd_backlight_125`, and leaving the USB keyboard interface in a detached state.
  * **Solution:** Re-run the updated `fedora-xmg-m25.sh` script. It contains a conflict patch for `clevo_leds.h` that disables the redundant ACPI-based LED registration, refreshes the `ite_8291` modules, resets the USB controller to restore driver bindings, and restarts the `tccd` daemon.

### 4. TCC `.desktop` files weren't patched (no files found)
* **Symptom:** Script completes but reports no `.desktop` files were patched for TCC.
* **Solution:** This means TCC wasn't installed before running the script. Install it first via the TUXEDO repository (see Prerequisites Step B), then re-run `fedora-xmg-m25.sh` to apply the patches.

### 5. NVIDIA drivers not detected after install (`nvidia-smi` fails)
* **Symptom:** `nvidia-smi` returns an error or the NVIDIA module isn't loaded after rebooting.
* **Solution:** The akmod build runs in the background after install. If you reboot before it finishes, the module won't be present. Check whether it's built before rebooting:
  ```bash
  modinfo -F version nvidia
  # Returns a version number = module is ready, safe to reboot
  # Returns nothing = build still in progress, wait and check again
  ```
  If the module is present but still doesn't load after reboot (RTX 4000/5000 series), try forcing the open kernel module build:
  ```bash
  sudo sh -c 'echo "%_with_kmod_nvidia_open 1" > /etc/rpm/macros.nvidia-kmod'
  sudo akmods --force && sudo reboot
  ```

---

## Disclaimer
These scripts are provided as-is, and you run them at your own risk. The author takes no responsibility for any data loss, hardware issues, system instability, or other problems that may arise from using them.

---

## License
These scripts are open-source and released under the **GNU General Public License v3 (GPLv3)**. Anyone is free to use, modify, and distribute these scripts, but any modifications or derivative works shared must also remain open-source under the GPLv3.
