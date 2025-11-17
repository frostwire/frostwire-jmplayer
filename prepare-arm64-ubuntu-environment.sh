#!/bin/bash
################################################################################
# Prepare Ubuntu ARM64 environment for building FrostWire FWPlayer
# Installs all dependencies needed for native ARM64 Linux builds
# Windows cross-compilation not supported on ARM64
################################################################################

# Verify we're on Ubuntu ARM64
if ! grep -q "Ubuntu" /etc/os-release 2>/dev/null; then
    echo "Error: This script is designed for Ubuntu Linux"
    exit 1
fi

if [ "$(uname -m)" != "aarch64" ]; then
    echo "Error: This script is designed for ARM64 (aarch64) architecture"
    exit 1
fi

echo "Setting up Ubuntu ARM64 build environment for FrostWire FWPlayer..."
echo ""

# Update package lists
echo "Updating package lists..."
sudo apt update
sudo apt install -y --fix-broken || true
sudo apt upgrade -y || true

################################################################################
# System Updates and Core Build Tools
################################################################################
echo "Installing core build tools..."
sudo apt install -y --no-install-recommends build-essential
sudo apt install -y --no-install-recommends pkg-config
sudo apt install -y --no-install-recommends git
sudo apt install -y --no-install-recommends ca-certificates
sudo apt install -y --no-install-recommends wget

################################################################################
# Compilation and Assembly Tools
################################################################################
echo "Installing compilation and assembly tools..."
sudo apt install -y --no-install-recommends yasm

################################################################################
# Native Linux Development Libraries
# (For native ARM64 Linux builds)
################################################################################
echo "Installing native Linux audio codec development libraries..."
sudo apt install -y --no-install-recommends libmad0-dev
sudo apt install -y --no-install-recommends liba52-dev
sudo apt install -y --no-install-recommends libvorbis-dev
sudo apt install -y --no-install-recommends libmp3lame-dev
sudo apt install -y --no-install-recommends libavcodec-dev
sudo apt install -y --no-install-recommends libavformat-dev
sudo apt install -y --no-install-recommends libavutil-dev
sudo apt install -y --no-install-recommends libswscale-dev
sudo apt install -y --no-install-recommends libswresample-dev
sudo apt install -y --no-install-recommends libxml2-dev
sudo apt install -y --no-install-recommends libzstd-dev
sudo apt install -y --no-install-recommends libsdl1.2-dev

echo ""
echo "======================================"
echo "Environment setup complete!"
echo "======================================"
echo ""
echo "=== Build Environment Verification ==="
echo "Platform: $(uname -m)"
echo "OS: $(cat /etc/os-release | grep PRETTY_NAME)"
echo ""
echo "Native compiler:"
gcc --version | head -1
echo ""
echo "Build tools:"
yasm --version | head -1
make --version | head -1
echo ""
echo "=== Environment ready for ARM64 Linux native build ==="
echo ""
echo "To build for Linux ARM64 native, run:"
echo "  ./build_linux.sh"
