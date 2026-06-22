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
* **Operating System:** Fedora KDE Spin (specifically using SDDM, KDE Plasma, and Wayland).
* **Network:** Active internet connection is required to fetch driver dependencies and clone repositories.
* **Privileges:** `sudo` access is required for installing dependencies, copying kernel modules, and patching system-level desktop shortcuts.
* **For DaVinci Resolve:** You must manually download the official **DaVinci Resolve Studio (Linux)** `.zip` installer from the Blackmagic Design website before running the install script.

---

## How the Scripts Relate to Each Other

```
fedora-resolve-installer.sh (Run this first)
  └── Unzips and executes Blackmagic .run GUI installer
  └── Triggers fedora-resolve-fix.sh automatically
        ├── Moves conflicting Fedora system glib/gio libraries to /opt/resolve/libs/disabled-libraries/
        ├── Patches system application .desktop shortcuts with NVIDIA PRIME flags
        └── Generates ~/resolve-launch.sh in your home directory (KDE appmenu workaround)
```

---

## 1. Hardware & Driver Control

### `fedora-xmg-m25.sh` (Tuxedo Drivers + Schenker DMI Patch)
A master installation script that pulls the latest `tuxedo-drivers` from Tuxedo's GitLab, patches them for compatibility, builds the modules using DKMS, and patches the Tuxedo Control Center (TCC) application to prevent crashes under Wayland.

* **What it does under the hood:**
  * Installs compilation dependencies: `git`, `dkms`, `make`, `gcc`, `fedora-repos-archive`, `python3`, and matching `kernel-devel`/`kernel-headers` packages.
  * Applies **three source patches**:
    1. *Intel Atom Header Fix:* Replaces `INTEL_ATOM_AIRMONT_MID` with `INTEL_ATOM_AIRMONT_NP` to maintain kernel compatibility.
    2. *GCC 14 Pointer Fix:* Removes strict pointer enforcement errors (`.owner = THIS_MODULE`) in `clevo_acpi.c`.
    3. *Schenker DMI Whitelist Bypass:* Automatically whitelists the Schenker board model (`X6PR5xxW_X6RP5xxW`) to allow Tuxedo drivers to run on XMG systems.
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
  * **Important:** Avoid installing or upgrading `tuxedo-drivers` packages directly via RPM repositories, as those packages will overwrite these custom-patched drivers and lack the Schenker DMI whitelist bypass and custom TDP limits.

---

## 2. DaVinci Resolve Studio Automation

### `fedora-resolve-installer.sh` (Automated Installer Wrapper)
Automates the entire DaVinci Resolve Studio installation process on Fedora. It extracts the installer, bypasses incompatible package checks (`SKIP_PACKAGE_CHECK=1`), executes the GUI installer, calls the fixer script, and performs post-install cleanup.

* **Requirements:** Place the downloaded DaVinci Resolve `.zip` installer in the same folder where you run this script.
* **Download & Run:**
  ```bash
  curl -L -o fedora-resolve-installer.sh https://raw.githubusercontent.com/DenisJosifoski/xmg-linux-scripts/main/fedora-resolve-installer.sh
  chmod +x fedora-resolve-installer.sh
  ./fedora-resolve-installer.sh
  ```

### `fedora-resolve-fix.sh` (Post-Install Fixer)
Solves library conflicts on Fedora (moves conflicting `glib` and `gio` libraries to a backup folder) and updates desktop application shortcuts to launch Resolve using NVIDIA discrete graphics. This is triggered automatically by the installer script, but can be run independently if needed.

* **Download & Run:**
  ```bash
  curl -L -o fedora-resolve-fix.sh https://raw.githubusercontent.com/DenisJosifoski/xmg-linux-scripts/main/fedora-resolve-fix.sh
  chmod +x fedora-resolve-fix.sh
  ./fedora-resolve-fix.sh
  ```

### `resolve-launch.sh` (KDE Launch Helper - Reference Snapshot Only)
A helper script generated in the user's home folder by the fixer script. It sets the proper NVIDIA prime environment variables and unloads/reloads the KDE global menu module (`appmenu`) to prevent keyboard lockouts when starting DaVinci Resolve 21 on KDE. 

> [!IMPORTANT]
> **Do not manually download this file.** The version in this repository serves as a reference snapshot. The script is automatically generated and written directly to `~/resolve-launch.sh` when you run `fedora-resolve-fix.sh`.

* **How to use:** Keep this script in your home folder. If you launch Resolve from the desktop/applications menu, the patched shortcut runs it automatically. If you want to launch from the terminal, run `~/resolve-launch.sh`.

---

## Troubleshooting

### 1. DKMS compilation/build fails during driver setup
* **Symptom:** The script exits with a compilation error, or the drivers fail to load after run.
* **Solution:** Ensure your kernel development packages match your running kernel. Run:
  ```bash
  sudo dnf install -y kernel-devel-$(uname -r) kernel-headers-$(uname -r)
  ```
  And then re-run the driver script.

### 2. DaVinci Resolve crashes immediately on launch
* **Symptom:** Clicking the DaVinci Resolve application shortcut flashes a loading cursor, then exits without opening a window.
* **Solution:** Run the generated launch script manually from a terminal to see the error output:
  ```bash
  bash ~/resolve-launch.sh
  ```
  If it outputs symbol lookup errors related to `glib` or `gio`, verify that `fedora-resolve-fix.sh` successfully moved those libraries out of `/opt/resolve/libs/`.

### 3. Tuxedo Control Center fails to open or crashes on Wayland
* **Symptom:** TCC starts in the background but the interface won't load or displays a blank window.
* **Solution:** The script patches the `.desktop` launchers with Wayland/Electron compatibility flags. Verify if the flags are set correctly by running it from the CLI:
  ```bash
  tuxedo-control-center --ozone-platform-hint=auto --disable-gpu
  ```
  *(Note: The `--disable-gpu` flag is applied automatically by the installer script depending on its NVIDIA driver version detection, which requires driver version ≥ 545 for hardware acceleration. The manual CLI command above is strictly for testing and verification purposes.)*
  
  If it loads successfully with `--disable-gpu`, check that the patched `.desktop` file matches this configuration.

---

## License
These scripts are open-source and released under the **GNU General Public License v3 (GPLv3)**. Anyone is free to use, modify, and distribute these scripts, but any modifications or derivative works shared must also remain open-source under the GPLv3.
