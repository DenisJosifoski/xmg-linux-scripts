#!/bin/bash
# ============================================================
# DaVinci Resolve Studio NVIDIA PRIME Fixer (Fedora)
# Automates environment variables for Hybrid Graphics
# ============================================================

set -euo pipefail

# 1. Configuration
RESOLVE_BIN="/opt/resolve/bin/resolve"
LAUNCH_SCRIPT="$HOME/resolve-launch.sh"
ENV_VARS="env __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia __VK_LAYER_NV_optimus=NVIDIA_only"

echo "============================================================"
echo " DaVinci Resolve Studio NVIDIA Fixer"
echo "============================================================"

# 2. Create/Update resolve-launch.sh
echo "[1/4] Creating/Updating $LAUNCH_SCRIPT..."
cat <<EOF > "$LAUNCH_SCRIPT"
#!/bin/bash
export __NV_PRIME_RENDER_OFFLOAD=1
export __GLX_VENDOR_LIBRARY_NAME=nvidia
export __VK_LAYER_NV_optimus=NVIDIA_only

# KDE Global Menu Workaround (Fixes keyboard lockout in DRS 21)
if command -v qdbus-qt6 &> /dev/null; then
    qdbus-qt6 org.kde.kded6 /kded org.kde.kded6.unloadModule "appmenu"
    $RESOLVE_BIN "\$@"
    qdbus-qt6 org.kde.kded6 /kded org.kde.kded6.loadModule "appmenu"
else
    $RESOLVE_BIN "\$@"
fi
EOF
chmod +x "$LAUNCH_SCRIPT"
echo "✅ Launch script ready."

# 3. Resolve Fedora Library Conflicts
echo "[2/4] Fixing Fedora library conflicts (glib/pango)..."
LIB_DIR="/opt/resolve/libs"
DISABLED_DIR="$LIB_DIR/disabled-libraries"

if [ -d "$LIB_DIR" ]; then
    sudo mkdir -p "$DISABLED_DIR"
    # List of libraries known to cause "symbol lookup error" on Fedora
    CONFLICTING_LIBS=(
        "libglib-2.0.so*"
        "libgio-2.0.so*"
        "libgmodule-2.0.so*"
        "libgobject-2.0.so*"
    )
    
    for LIB in "${CONFLICTING_LIBS[@]}"; do
        # Use find to check if files exist before moving to avoid error messages
        if sudo find "$LIB_DIR" -maxdepth 1 -name "$LIB" -print -quit | grep -q .; then
            echo "  → Disabling: $LIB"
            sudo mv $LIB_DIR/$LIB "$DISABLED_DIR/" 2>/dev/null || true
        fi
    done
    echo "✅ Library conflicts resolved."
else
    echo "  → Skipping library fix (Resolve directory not found)."
fi

# 4. Patch Desktop Entries
echo "[3/4] Patching Desktop entries..."

DESKTOP_FILES=(
    "/usr/share/applications/com.blackmagicdesign.resolve.desktop"
    "$HOME/.local/share/applications/com.blackmagicdesign.resolve.desktop"
    "$HOME/Desktop/com.blackmagicdesign.resolve.desktop"
)

for FILE in "${DESKTOP_FILES[@]}"; do
    if [ -f "$FILE" ]; then
        echo "  → Patching: $FILE"
        # Remove any existing env prefixes or custom launch script references to ensure a clean state
        # Then apply the standard NVIDIA PRIME offload command
        sudo sed -i "s|^Exec=.*|Exec=$ENV_VARS $RESOLVE_BIN %u|" "$FILE"
        
        # Ensure correct ownership for user files
        if [[ "$FILE" == "$HOME"* ]]; then
            chown $(id -u):$(id -g) "$FILE"
        fi
    else
        echo "  → Skipping (not found): $FILE"
    fi
done

# 5. Refresh Desktop Database
echo "[4/4] Refreshing desktop database..."
if command -v update-desktop-database &> /dev/null; then
    update-desktop-database "$HOME/.local/share/applications/" || true
fi

echo "============================================================"
echo "🎉 Setup Complete!"
echo "DaVinci Resolve is now configured for NVIDIA Discrete Graphics."
echo "You can launch it from the menu, desktop, or via terminal."
echo "============================================================"
