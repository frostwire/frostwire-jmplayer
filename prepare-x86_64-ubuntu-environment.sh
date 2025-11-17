#!/bin/bash
################################################################################
# Prepare Ubuntu x86_64 environment for building FrostWire FWPlayer
# Installs all dependencies needed for cross-compilation to Windows x86_64
# using mingw32 and for native Linux builds
################################################################################

# Verify we're on Ubuntu x86_64
if ! grep -q "Ubuntu" /etc/os-release 2>/dev/null; then
    echo "Error: This script is designed for Ubuntu Linux"
    exit 1
fi

if [ "$(uname -m)" != "x86_64" ]; then
    echo "Error: This script is designed for x86_64 architecture"
    exit 1
fi

echo "Setting up Ubuntu x86_64 build environment for FrostWire FWPlayer..."
echo ""

# Update package lists
echo "Updating package lists..."
sudo apt update

################################################################################
# Core Build Tools
################################################################################
echo "Installing core build tools..."
sudo apt install -y build-essential pkg-config yasm upx git

################################################################################
# MinGW-w64 Cross-Compilation Toolchain (for Windows builds)
################################################################################
echo "Installing MinGW-w64 cross-compilation toolchain..."
sudo apt install -y mingw-w64 mingw-w64-tools mingw-w64-common
sudo apt install -y mingw-w64-i686-dev mingw-w64-x86-64-dev

################################################################################
# Native Linux Development Libraries
# (For reference and potential native Linux builds)
################################################################################
echo "Installing native Linux audio codec development libraries..."
sudo apt install -y libmad0-dev liba52-dev libvorbis-dev libmp3lame-dev
sudo apt install -y libavcodec-dev libavformat-dev libavutil-dev
sudo apt install -y libswscale-dev libswresample-dev
sudo apt install -y libxml2-dev libzstd-dev libsdl1.2-dev

################################################################################
# MinGW-w64 Audio Codec Libraries (for Windows cross-compilation)
################################################################################
echo "Installing MinGW-w64 audio codec libraries..."

# These packages should provide the static libraries needed for Windows builds
# Package naming convention: mingw-w64-x86-64-{library}-dev
sudo apt install -y mingw-w64-x86-64-zlib-dev || true

# Note: Not all audio codec libraries have mingw-w64 packages in standard repos
# They may need to be compiled separately or obtained from other sources
# Attempting to install if available:
sudo apt install -y mingw-w64-x86-64-libogg-dev || echo "Warning: mingw-w64 libogg-dev not available"
sudo apt install -y mingw-w64-x86-64-libvorbis-dev || echo "Warning: mingw-w64 libvorbis-dev not available"

echo ""
echo "======================================"
echo "Environment setup complete!"
echo "======================================"
echo ""
echo "Verify MinGW-w64 installation:"
which x86_64-w64-mingw32-gcc
x86_64-w64-mingw32-gcc --version
echo ""
echo "To build for Windows, run:"
echo "  ./build_windows.sh"
echo ""
echo "To build for Linux native, run:"
echo "  ./build_linux.sh"
