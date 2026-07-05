#!/bin/bash
# ============================================================
# DaVinci Resolve Studio Automated Installer (Fedora)
# 1. Unzips installer 2. Installs dependencies 3. Runs installer 4. Triggers Fixer
# ============================================================

set -euo pipefail

echo "============================================================"
echo " DaVinci Resolve Studio Full Automation Installer"
echo "============================================================"

# 1. Find the ZIP file
ZIP_FILE=$(ls DaVinci_Resolve_Studio_*_Linux.zip 2>/dev/null | head -n 1)

if [ -z "$ZIP_FILE" ]; then
    echo "❌ Error: No DaVinci_Resolve_Studio_*.zip found in the current directory."
    echo "   Please run this script from the folder containing the ZIP."
    exit 1
fi

echo "[1/5] Unzipping $ZIP_FILE..."
# -o overwrites without asking, -q is quiet
unzip -oq "$ZIP_FILE"
echo "✅ Unzipped successfully."

# 2. Find the .run file
RUN_FILE=$(ls DaVinci_Resolve_Studio_*_Linux.run 2>/dev/null | head -n 1)

if [ -z "$RUN_FILE" ]; then
    echo "❌ Error: Could not find the .run installer file after unzipping."
    exit 1
fi

# 3. Install System Dependencies
echo "[2/5] Installing legacy system dependencies (libxcrypt-compat)..."
sudo dnf install -y libxcrypt-compat

# 4. Run the Installer
echo "[3/5] Launching installer (Bypassing package check)..."
echo "      Please follow the GUI prompts to complete installation."
chmod +x "$RUN_FILE"
sudo SKIP_PACKAGE_CHECK=1 ./"$RUN_FILE"
echo "✅ Installation process finished."

# 5. Run the Fixer Script
# Check current directory first, then fallback to HOME
FIX_SCRIPT_NAME="fedora-resolve-fix.sh"
FIX_SCRIPT_PATH=""

if [ -f "$(dirname "$0")/$FIX_SCRIPT_NAME" ]; then
    FIX_SCRIPT_PATH="$(dirname "$0")/$FIX_SCRIPT_NAME"
elif [ -f "$HOME/$FIX_SCRIPT_NAME" ]; then
    FIX_SCRIPT_PATH="$HOME/$FIX_SCRIPT_NAME"
fi

if [ -n "$FIX_SCRIPT_PATH" ]; then
    echo "[4/5] Running GPU & Keyboard Fixer ($FIX_SCRIPT_PATH)..."
    bash "$FIX_SCRIPT_PATH"
    echo "✅ System patched successfully."
else
    echo "⚠️ Warning: Fixer script ($FIX_SCRIPT_NAME) not found in current dir or $HOME. Skipping patching."
fi

# 6. Cleanup (Optional)
echo "[5/5] Cleaning up installer file..."
rm "$RUN_FILE"
echo "✅ Cleanup complete."

echo "============================================================"
echo "🎉 ALL DONE!"
echo "DaVinci Resolve Studio is installed and fully patched."
echo "You can launch it from your Applications menu."
echo "============================================================"
