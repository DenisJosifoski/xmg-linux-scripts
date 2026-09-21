#!/usr/bin/env bash
# ==============================================================================
# Fedora KDE & XMG M25 Setup Toolkit - Master Installer & Control Menu
# Repository: https://github.com/DenisJosifoski/xmg-linux-scripts
# ==============================================================================

set -u

# Resolve current script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color codes for readable formatting
C_RESET='\033[0m'
C_BOLD='\033[1m'
C_GREEN='\033[32m'
C_BLUE='\033[34m'
C_CYAN='\033[36m'
C_YELLOW='\033[33m'
C_RED='\033[31m'

# Helper: print banners
print_header() {
    clear 2>/dev/null || true
    echo -e "${C_CYAN}${C_BOLD}==================================================================${C_RESET}"
    echo -e "${C_BOLD}     Fedora KDE & XMG M25 Setup Toolkit (Master Menu)            ${C_RESET}"
    echo -e "${C_CYAN}${C_BOLD}==================================================================${C_RESET}"
    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        echo -e " System: ${C_GREEN}${PRETTY_NAME:-Linux}${C_RESET} | Kernel: ${C_GREEN}$(uname -r)${C_RESET}"
    fi
    echo -e "${C_CYAN}------------------------------------------------------------------${C_RESET}"
}

# Helper: pause and wait for Enter
press_enter() {
    echo
    echo -e "${C_YELLOW}Press [Enter] to return to the menu...${C_RESET}"
    read -r
}

# Helper: ensure script exists and is executable
check_and_prep_script() {
    local script_name="$1"
    local full_path="${SCRIPT_DIR}/${script_name}"
    if [ ! -f "$full_path" ]; then
        echo -e "${C_RED}Error: Script '${script_name}' not found in ${SCRIPT_DIR}.${C_RESET}"
        return 1
    fi
    chmod +x "$full_path"
    return 0
}

# 1. XMG M25 Drivers & TCC Patch
option_xmg_drivers() {
    echo -e "\n${C_BOLD}[1] Running XMG M25 Drivers & TCC Patch (fedora-xmg-m25.sh)...${C_RESET}"
    echo "This script compiles Tuxedo kernel drivers with custom Schenker DMI whitelist,"
    echo "applies M25 power limits, and patches TUXEDO Control Center for Wayland."
    echo
    if check_and_prep_script "fedora-xmg-m25.sh"; then
        sudo bash "${SCRIPT_DIR}/fedora-xmg-m25.sh"
    fi
    press_enter
}

# 2. S2idle Sleep & Battery Drain Fix
option_sleep_fixes() {
    echo -e "\n${C_BOLD}[2] Running Sleep & Battery Drain Fix (apply_fixes.sh)...${C_RESET}"
    echo "This script configures NVIDIA S0ix power management, enables suspend services,"
    echo "fixes lock-screen freezing with nvidia-drm.fbdev=1, disables runaway ACPI"
    echo "wakeups, and rebuilds initramfs with dracut."
    echo
    if check_and_prep_script "apply_fixes.sh"; then
        sudo bash "${SCRIPT_DIR}/apply_fixes.sh"
    fi
    press_enter
}

# 3. XMG Backlight Sleep Hook
option_backlight_hook() {
    echo -e "\n${C_BOLD}[3] Installing XMG Keyboard Backlight Resume Hook (xmg-backlight-resume.sh)...${C_RESET}"
    echo "This hook restores custom keyboard RGB color profiles upon waking from sleep."
    echo -e "${C_YELLOW}Note: Requires /usr/local/lib/xmg-backlight-venv/ to be configured.${C_RESET}"
    echo
    if check_and_prep_script "xmg-backlight-resume.sh"; then
        read -r -p "Install sleep hook to /usr/lib/systemd/system-sleep/? [y/N]: " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            sudo cp "${SCRIPT_DIR}/xmg-backlight-resume.sh" /usr/lib/systemd/system-sleep/xmg-backlight-resume.sh
            sudo chmod +x /usr/lib/systemd/system-sleep/xmg-backlight-resume.sh
            if command -v restorecon &>/dev/null; then
                sudo restorecon -v /usr/lib/systemd/system-sleep/xmg-backlight-resume.sh 2>/dev/null || true
            fi
            echo -e "${C_GREEN}✓ Hook successfully installed into /usr/lib/systemd/system-sleep/${C_RESET}"
        else
            echo "Installation cancelled."
        fi
    fi
    press_enter
}

# 4. DaVinci Resolve Full Installer
option_resolve_installer() {
    echo -e "\n${C_BOLD}[4] Running DaVinci Resolve Studio Installer (fedora-resolve-installer.sh)...${C_RESET}"
    echo "Unzips the Linux Studio installer, installs dependencies (libxcrypt-compat),"
    echo "runs the installer with package checks bypassed, and runs the GPU fixer."
    echo -e "${C_YELLOW}Ensure 'DaVinci_Resolve_Studio_*_Linux.zip' is placed in this folder.${C_RESET}"
    echo
    if check_and_prep_script "fedora-resolve-installer.sh"; then
        bash "${SCRIPT_DIR}/fedora-resolve-installer.sh"
    fi
    press_enter
}

# 5. DaVinci Resolve Fixer Only
option_resolve_fixer() {
    echo -e "\n${C_BOLD}[5] Running DaVinci Resolve Fixer (fedora-resolve-fix.sh)...${C_RESET}"
    echo "Disables conflicting Fedora glib/gio libraries, configures NVIDIA discrete GPU"
    echo "launchers, creates ~/resolve-launch.sh, and forces window title bars in KDE Plasma."
    echo
    if check_and_prep_script "fedora-resolve-fix.sh"; then
        bash "${SCRIPT_DIR}/fedora-resolve-fix.sh"
    fi
    press_enter
}

# 6. Video Audio Prep for Resolve
option_prepare_resolve() {
    echo -e "\n${C_BOLD}[6] Running Video Audio Transcoder for Resolve (prepare-for-resolve.sh)...${C_RESET}"
    echo "Losslessly remuxes audio from AAC to PCM (pcm_s16le) without re-encoding video."
    echo
    read -r -p "Enter path to folder containing videos (default: current directory): " user_target
    user_target="${user_target:-.}"
    if check_and_prep_script "prepare-for-resolve.sh"; then
        bash "${SCRIPT_DIR}/prepare-for-resolve.sh" "$user_target"
    fi
    press_enter
}

# 7. Antigravity IDE Fixer
option_antigravity_fix() {
    echo -e "\n${C_BOLD}[7] Running Antigravity IDE Fixer (fedora-antigravity-fix.sh)...${C_RESET}"
    echo "Swaps out buggy @parcel/watcher v2.5.1 with stable v2.5.6 to permanently stop"
    echo "segmentation faults, coredump file bloat, and 90°C+ CPU spikes on IDE exit."
    echo
    if check_and_prep_script "fedora-antigravity-fix.sh"; then
        sudo bash "${SCRIPT_DIR}/fedora-antigravity-fix.sh"
    fi
    press_enter
}

# 8. OpenRazer Mouse Dock Pro Installer
option_openrazer() {
    echo -e "\n${C_BOLD}[8] OpenRazer PR #2817 Mouse Dock Pro Passthrough (fedora-openrazer.sh)...${C_RESET}"
    echo "Builds and installs karaktaka's DKMS driver & daemon with full Mouse Dock Pro relay."
    echo "  1) Install / Upgrade PR #2817 driver"
    echo "  2) Rollback to official OpenRazer 3.12.4"
    echo "  3) Cancel"
    read -r -p "Select action [1-3]: " sub_choice
    case "$sub_choice" in
        1)
            if check_and_prep_script "fedora-openrazer.sh"; then
                bash "${SCRIPT_DIR}/fedora-openrazer.sh" install
            fi
            ;;
        2)
            if check_and_prep_script "fedora-openrazer.sh"; then
                bash "${SCRIPT_DIR}/fedora-openrazer.sh" rollback
            fi
            ;;
        *)
            echo "Action cancelled."
            ;;
    esac
    press_enter
}

# 9. Razer Autosuspend & PowerTOP Fix
option_razer_autosuspend() {
    echo -e "\n${C_BOLD}[9] Running Razer USB Autosuspend Fix (fix-razer-autosuspend.sh)...${C_RESET}"
    echo "Configures udev rules to stop the Razer Basilisk V3 Pro and internal USB hub"
    echo "from dropping connection due to USB autosuspend or PowerTOP rules."
    echo
    if check_and_prep_script "fix-razer-autosuspend.sh"; then
        sudo bash "${SCRIPT_DIR}/fix-razer-autosuspend.sh"
    fi
    press_enter
}

# Guided Installation Wizard
guided_wizard() {
    clear 2>/dev/null || true
    echo -e "${C_CYAN}${C_BOLD}==================================================================${C_RESET}"
    echo -e "${C_BOLD}                 Guided Setup Wizard                             ${C_RESET}"
    echo -e "${C_CYAN}${C_BOLD}==================================================================${C_RESET}"
    echo "This step-by-step wizard will ask you simple Yes/No questions to"
    echo "set up only the components that match your hardware and applications."
    echo

    # Step 1: XMG Drivers
    read -r -p "1. Are you on an XMG Pro 16 VE M25 and want to install/patch Tuxedo drivers? [y/N]: " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        sudo bash "${SCRIPT_DIR}/fedora-xmg-m25.sh"
    fi

    # Step 2: Sleep fixes
    echo
    read -r -p "2. Would you like to fix S2idle battery drain during sleep & Wayland wake freeze? [y/N]: " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        sudo bash "${SCRIPT_DIR}/apply_fixes.sh"
    fi

    # Step 3: Backlight hook
    echo
    read -r -p "3. Do you use custom XMG RGB backlight script and want sleep/resume profile restoration? [y/N]: " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        sudo cp "${SCRIPT_DIR}/xmg-backlight-resume.sh" /usr/lib/systemd/system-sleep/xmg-backlight-resume.sh
        sudo chmod +x /usr/lib/systemd/system-sleep/xmg-backlight-resume.sh
        echo -e "${C_GREEN}✓ Backlight hook installed.${C_RESET}"
    fi

    # Step 4: DaVinci Resolve
    echo
    read -r -p "4. Do you want to install or patch DaVinci Resolve Studio? [y/N]: " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        read -r -p "   Run Full Installer (i) or just apply NVIDIA/KWin Fixes (f)? [i/f]: " res_ans
        if [[ "$res_ans" =~ ^[Ii]$ ]]; then
            bash "${SCRIPT_DIR}/fedora-resolve-installer.sh"
        elif [[ "$res_ans" =~ ^[Ff]$ ]]; then
            bash "${SCRIPT_DIR}/fedora-resolve-fix.sh"
        fi
    fi

    # Step 5: Antigravity
    echo
    read -r -p "5. Do you use Google Antigravity IDE and want to fix CPU overheating on exit? [y/N]: " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        sudo bash "${SCRIPT_DIR}/fedora-antigravity-fix.sh"
    fi

    # Step 6: Razer Mouse & Dock
    echo
    read -r -p "6. Do you use a Razer Mouse with Mouse Dock Pro? [y/N]: " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        bash "${SCRIPT_DIR}/fedora-openrazer.sh" install
        echo
        read -r -p "   Also apply USB autosuspend & PowerTOP fix for Razer mice? [y/N]: " ans_usb
        if [[ "$ans_usb" =~ ^[Yy]$ ]]; then
            sudo bash "${SCRIPT_DIR}/fix-razer-autosuspend.sh"
        fi
    fi

    echo -e "\n${C_GREEN}${C_BOLD}Guided setup complete!${C_RESET}"
    press_enter
}

# Run All Core Recommended Fixes (Drivers + Sleep)
run_core_recommended() {
    clear 2>/dev/null || true
    echo -e "${C_CYAN}${C_BOLD}==================================================================${C_RESET}"
    echo -e "${C_BOLD}         Applying All Core Laptop Fixes (Drivers + Sleep)        ${C_RESET}"
    echo -e "${C_CYAN}${C_BOLD}==================================================================${C_RESET}"
    echo "1/2 Running fedora-xmg-m25.sh..."
    if check_and_prep_script "fedora-xmg-m25.sh"; then
        sudo bash "${SCRIPT_DIR}/fedora-xmg-m25.sh"
    fi
    echo
    echo "2/2 Running apply_fixes.sh..."
    if check_and_prep_script "apply_fixes.sh"; then
        sudo bash "${SCRIPT_DIR}/apply_fixes.sh"
    fi
    echo -e "\n${C_GREEN}${C_BOLD}All core laptop fixes applied successfully! Please reboot your system.${C_RESET}"
    press_enter
}

# Main menu loop
while true; do
    print_header
    echo -e "${C_BOLD}  [Core Laptop & Hardware]${C_RESET}"
    echo "   1) XMG M25 Drivers & TCC Patch             (fedora-xmg-m25.sh)"
    echo "   2) Sleep & S2idle Battery Drain Fixes      (apply_fixes.sh)"
    echo "   3) Install Keyboard Backlight Resume Hook  (xmg-backlight-resume.sh)"
    echo
    echo -e "${C_BOLD}  [Applications & Workarounds]${C_RESET}"
    echo "   4) DaVinci Resolve Studio Full Installer   (fedora-resolve-installer.sh)"
    echo "   5) DaVinci Resolve GPU & KDE Titlebar Fix  (fedora-resolve-fix.sh)"
    echo "   6) Transcode Video Audio (AAC → PCM)       (prepare-for-resolve.sh)"
    echo "   7) Antigravity IDE Exit Crash Fixer        (fedora-antigravity-fix.sh)"
    echo
    echo -e "${C_BOLD}  [Razer Peripherals (Optional)]${C_RESET}"
    echo "   8) OpenRazer Mouse Dock Pro Driver         (fedora-openrazer.sh)"
    echo "   9) Razer USB Autosuspend / PowerTOP Fix    (fix-razer-autosuspend.sh)"
    echo
    echo -e "${C_BOLD}  [Automated Workflows]${C_RESET}"
    echo "   G) Guided Setup Wizard (interactive step-by-step)"
    echo "   A) Apply Recommended Core Laptop Fixes (1 + 2)"
    echo "   Q) Quit"
    echo -e "${C_CYAN}------------------------------------------------------------------${C_RESET}"
    read -r -p "Enter choice [1-9, G, A, Q]: " choice

    case "$choice" in
        1) option_xmg_drivers ;;
        2) option_sleep_fixes ;;
        3) option_backlight_hook ;;
        4) option_resolve_installer ;;
        5) option_resolve_fixer ;;
        6) option_prepare_resolve ;;
        7) option_antigravity_fix ;;
        8) option_openrazer ;;
        9) option_razer_autosuspend ;;
        [Gg]) guided_wizard ;;
        [Aa]) run_core_recommended ;;
        [Qq])
            echo -e "\nExiting. Goodbye!\n"
            exit 0
            ;;
        *)
            echo -e "\n${C_RED}Invalid selection. Please enter a valid option.${C_RESET}"
            sleep 1
            ;;
    esac
done
