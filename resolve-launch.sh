#!/bin/bash
export __NV_PRIME_RENDER_OFFLOAD=1
export __GLX_VENDOR_LIBRARY_NAME=nvidia
export __VK_LAYER_NV_optimus=NVIDIA_only

# KDE Global Menu Workaround (Fixes keyboard lockout in DRS 21)
if command -v qdbus-qt6 &> /dev/null; then
    qdbus-qt6 org.kde.kded6 /kded org.kde.kded6.unloadModule "appmenu"
    /opt/resolve/bin/resolve "$@"
    qdbus-qt6 org.kde.kded6 /kded org.kde.kded6.loadModule "appmenu"
else
    /opt/resolve/bin/resolve "$@"
fi
