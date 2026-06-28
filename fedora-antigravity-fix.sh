#!/usr/bin/env bash
#
# fedora-antigravity-fix.sh
#
# Description:
#   Surgically patches Antigravity IDE on Fedora KDE to resolve a critical CPU spike
#   and hardware stress (90°C+) occurring on application exit.
#
# Root Cause:
#   The IDE bundles @parcel/watcher v2.5.1, which has a known teardown race condition
#   on Linux, triggering a SIGSEGV in node.mojom.NodeService. This crash prompts
#   systemd-coredump to compress and write a massive multi-gigabyte coredump,
#   causing extreme CPU usage.
#
# Fix:
#   Downloads @parcel/watcher v2.5.6 (x64-glibc) from npm registry, extracts the
#   stable native C++ node module (watcher.node), and swaps it into the IDE's
#   node_modules folder. Finally, configures the .desktop shortcuts.
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Antigravity IDE Exit Crash Fixer ===${NC}"

# Ensure script is run with sudo/root privileges
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run with sudo or as root.${NC}"
    echo "Usage: sudo $0"
    exit 1
fi

IDE_PATH="/opt/antigravity-ide"
TARGET_WATCHER_DIR="${IDE_PATH}/resources/app/node_modules/@parcel/watcher/build/Release"
TARGET_WATCHER="${TARGET_WATCHER_DIR}/watcher.node"

# 1. Verify or automatically install Antigravity IDE
if [ ! -d "$IDE_PATH" ]; then
    echo -e "${BLUE}Antigravity IDE not found at ${IDE_PATH}.${NC}"
    echo -e "${BLUE}Attempting to locate installation tarball in Downloads...${NC}"
    
    # Resolve user's download directory
    USER_HOME=$(eval echo "~${SUDO_USER:-root}")
    DOWNLOADS_DIR="${USER_HOME}/Downloads"
    
    # Look for the tarball
    TARBALL=$(find "$DOWNLOADS_DIR" -maxdepth 1 -name "Antigravity*.tar.gz" | head -n 1)
    
    if [ -z "$TARBALL" ]; then
        echo -e "${BLUE}No local tarball found. Querying AUR for the latest Antigravity IDE version...${NC}"
        
        # Query latest version and build number from the community-maintained AUR PKGBUILD
        PKGBUILD_DATA=$(curl -sL "https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=antigravity-ide" || true)
        LATEST_VER=$(echo "$PKGBUILD_DATA" | grep -E '^pkgver=' | cut -d= -f2 || true)
        LATEST_BUILD=$(echo "$PKGBUILD_DATA" | grep -E '^_build=' | cut -d= -f2 || true)
        
        if [ -n "$LATEST_VER" ] && [ -n "$LATEST_BUILD" ]; then
            echo -e "${GREEN}Detected latest version: ${LATEST_VER} (Build: ${LATEST_BUILD})${NC}"
            IDE_URL="https://dl.google.com/release2/j0qc3/antigravity/stable/${LATEST_VER}-${LATEST_BUILD}/linux-x64/Antigravity%20IDE.tar.gz"
        else
            echo -e "${BLUE}Could not retrieve latest version from AUR. Using fallback v2.1.1.${NC}"
            IDE_URL="https://dl.google.com/release2/j0qc3/antigravity/stable/2.1.1-6123990880747520/linux-x64/Antigravity%20IDE.tar.gz"
        fi
        
        TARBALL="${DOWNLOADS_DIR}/Antigravity IDE.tar.gz"
        
        # Ensure Downloads directory exists
        mkdir -p "$DOWNLOADS_DIR"
        
        echo -e "${BLUE}Downloading Antigravity IDE automatically...${NC}"
        if ! curl -L "$IDE_URL" -o "$TARBALL"; then
            echo -e "${RED}Error: Failed to download Antigravity IDE from ${IDE_URL}.${NC}"
            exit 1
        fi
        
        # Set ownership of the downloaded tarball to user
        if [ -n "${SUDO_USER:-}" ]; then
            chown "${SUDO_USER}:${SUDO_USER}" "$TARBALL"
        fi
    fi

    echo -e "${GREEN}Using tarball: ${TARBALL}${NC}"
    echo -e "${BLUE}Extracting to /opt/...${NC}"
    
    # Create a temporary extraction directory
    EXTRACT_TEMP=$(mktemp -d)
    tar -xzf "$TARBALL" -C "$EXTRACT_TEMP"
    
    # Determine the extracted folder name (usually 'Antigravity IDE')
    EXTRACTED_FOLDER=$(find "$EXTRACT_TEMP" -mindepth 1 -maxdepth 1 -type d | head -n 1)
    
    if [ -n "$EXTRACTED_FOLDER" ]; then
        mv "$EXTRACTED_FOLDER" "$IDE_PATH"
        rm -rf "$EXTRACT_TEMP"
        
        # Set initial ownership to the user
        if [ -n "${SUDO_USER:-}" ]; then
            chown -R "${SUDO_USER}:${SUDO_USER}" "$IDE_PATH"
        fi
        echo -e "${GREEN}Successfully installed Antigravity IDE to ${IDE_PATH}.${NC}"
    else
        echo -e "${RED}Error: Failed to find extracted folder in tarball.${NC}"
        rm -rf "$EXTRACT_TEMP"
        exit 1
    fi
fi

if [ ! -d "$TARGET_WATCHER_DIR" ]; then
    mkdir -p "$TARGET_WATCHER_DIR"
fi

# 2. Download and extract stable @parcel/watcher v2.5.6
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

echo -e "${BLUE}Downloading stable @parcel/watcher (v2.5.6) binary from registry.npmjs.org...${NC}"
TARBALL_URL="https://registry.npmjs.org/@parcel/watcher-linux-x64-glibc/-/watcher-linux-x64-glibc-2.5.6.tgz"

if ! curl -L "$TARBALL_URL" -o "${TEMP_DIR}/watcher-fix.tgz"; then
    echo -e "${RED}Error: Failed to download the package from npm.${NC}"
    exit 1
fi

echo -e "${BLUE}Extracting package...${NC}"
tar -xzf "${TEMP_DIR}/watcher-fix.tgz" -C "$TEMP_DIR"

if [ ! -f "${TEMP_DIR}/package/watcher.node" ]; then
    echo -e "${RED}Error: Extracted tarball did not contain package/watcher.node.${NC}"
    exit 1
fi

# 3. Apply the Surgical Patch (backup existing binary first)
if [ -f "$TARGET_WATCHER" ]; then
    echo -e "${BLUE}Backing up existing watcher.node to watcher.node.bak...${NC}"
    cp "$TARGET_WATCHER" "${TARGET_WATCHER}.bak"
fi

echo -e "${BLUE}Applying patched watcher.node...${NC}"
cp "${TEMP_DIR}/package/watcher.node" "$TARGET_WATCHER"
chmod 755 "$TARGET_WATCHER"

# Ensure the correct ownership is preserved
# If SUDO_USER is set (i.e. run via sudo), match their ownership, otherwise default to root:root
if [ -n "${SUDO_USER:-}" ]; then
    chown "${SUDO_USER}:${SUDO_USER}" "$TARGET_WATCHER"
else
    chown root:root "$TARGET_WATCHER"
fi

echo -e "${GREEN}Surgical binary patch successfully applied!${NC}"

# 4. Create and patch system-wide .desktop entry
DESKTOP_PATH="/usr/share/applications/antigravity-ide.desktop"
echo -e "${BLUE}Updating system desktop entry at ${DESKTOP_PATH}...${NC}"

cat <<EOF > "$DESKTOP_PATH"
[Desktop Entry]
Name=Antigravity IDE (Patched)
Comment=Professional Development Environment (Surgically Patched)
Exec=${IDE_PATH}/antigravity-ide %F
Icon=${IDE_PATH}/resources/app/resources/linux/code.png
Type=Application
Categories=Development;IDE;
Terminal=false
StartupNotify=true
MimeType=text/plain;inode/directory;
EOF
chmod 644 "$DESKTOP_PATH"

# 5. Create Desktop shortcut for the active user if they have a Desktop directory
if [ -n "${SUDO_USER:-}" ]; then
    USER_HOME=$(eval echo "~${SUDO_USER}")
    USER_DESKTOP="${USER_HOME}/Desktop"
    if [ -d "$USER_DESKTOP" ]; then
        echo -e "${BLUE}Creating Desktop shortcut for user '${SUDO_USER}'...${NC}"
        cp "$DESKTOP_PATH" "${USER_DESKTOP}/antigravity-ide.desktop"
        chown "${SUDO_USER}:${SUDO_USER}" "${USER_DESKTOP}/antigravity-ide.desktop"
        chmod +x "${USER_DESKTOP}/antigravity-ide.desktop"
        # Mark as trusted (KDE specific)
        sudo -u "$SUDO_USER" gio set "${USER_DESKTOP}/antigravity-ide.desktop" metadata::trusted true 2>/dev/null || true
    fi
fi

echo -e "${GREEN}=== Fix successfully applied! ===${NC}"
echo "You can now exit and run Antigravity IDE safely without shutdown crashes or CPU spikes."
