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
echo "[1/5] Creating/Updating $LAUNCH_SCRIPT..."
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
echo "[2/5] Fixing Fedora library conflicts (glib/pango)..."
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
echo "[3/5] Patching Desktop entries..."

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

# 5. Add KWin Window Rule (KDE Titlebar Fix)
echo "[4/5] Checking for KDE Plasma and setting KWin Window Rule..."
KWRITE_CMD=""
KREAD_CMD=""

if command -v kwriteconfig6 &>/dev/null && command -v kreadconfig6 &>/dev/null; then
    KWRITE_CMD="kwriteconfig6"
    KREAD_CMD="kreadconfig6"
elif command -v kwriteconfig5 &>/dev/null && command -v kreadconfig5 &>/dev/null; then
    KWRITE_CMD="kwriteconfig5"
    KREAD_CMD="kreadconfig5"
fi

if [ -n "$KWRITE_CMD" ]; then
    KWINRULES_FILE="$HOME/.config/kwinrulesrc"
    
    if [ -f "$KWINRULES_FILE" ] && grep -q "Description=DaVinci Resolve Show Titlebar" "$KWINRULES_FILE"; then
        echo "  → KWin rule for DaVinci Resolve titlebar already exists."
    else
        echo "  → Adding KWin rule to force DaVinci Resolve titlebar..."
        
        CURRENT_RULES=$($KREAD_CMD --file kwinrulesrc --group "General" --key "rules")
        RULE_ID="davinci-resolve-titlebar"
        
        if [ -z "$CURRENT_RULES" ]; then
            NEW_RULES="$RULE_ID"
        else
            if [[ "$CURRENT_RULES" != *"$RULE_ID"* ]]; then
                NEW_RULES="${CURRENT_RULES},$RULE_ID"
            else
                NEW_RULES="$CURRENT_RULES"
            fi
        fi
        
        $KWRITE_CMD --file kwinrulesrc --group "General" --key "rules" "$NEW_RULES"
        $KWRITE_CMD --file kwinrulesrc --group "$RULE_ID" --key "Description" "DaVinci Resolve Show Titlebar"
        $KWRITE_CMD --file kwinrulesrc --group "$RULE_ID" --key "noborder" "false"
        $KWRITE_CMD --file kwinrulesrc --group "$RULE_ID" --key "noborderrule" "2"
        $KWRITE_CMD --file kwinrulesrc --group "$RULE_ID" --key "wmclass" "resolve"
        $KWRITE_CMD --file kwinrulesrc --group "$RULE_ID" --key "wmclasscomplete" "false"
        $KWRITE_CMD --file kwinrulesrc --group "$RULE_ID" --key "wmclassmatch" "1"
        
        if command -v qdbus-qt6 &> /dev/null; then
            echo "  → Reloading KWin configuration..."
            qdbus-qt6 org.kde.KWin /KWin reconfigure
        elif command -v qdbus &> /dev/null; then
            echo "  → Reloading KWin configuration..."
            qdbus org.kde.KWin /KWin reconfigure
        fi
        echo "✅ KWin Window Rule applied successfully."
    fi
else
    echo "  → Skipping KWin rule (Not running KDE Plasma or configuration tools not found)."
fi

# 6. Refresh Desktop Database
echo "[5/5] Refreshing desktop database..."
if command -v update-desktop-database &> /dev/null; then
    update-desktop-database "$HOME/.local/share/applications/" || true
fi

echo "============================================================"
echo "🎉 Setup Complete!"
echo "DaVinci Resolve is now configured for NVIDIA Discrete Graphics."
echo "You can launch it from the menu, desktop, or via terminal."
echo "============================================================"
