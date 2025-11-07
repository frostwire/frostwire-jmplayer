#!/bin/bash
################################################################################
# Prepare macOS environment for FWPlayer builds
# Installs necessary build tools and audio codec libraries via Homebrew
################################################################################

set -e

echo "Setting up macOS build environment..."

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "Homebrew not found. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

echo "Installing build tools..."
brew install yasm upx 2>/dev/null || true

echo "Installing audio codec libraries..."
brew install mad a52dec libvorbis lame 2>/dev/null || true

echo "Installing other dependencies..."
brew install libxml2 sdl 2>/dev/null || true

echo "✓ macOS build environment ready!"
echo ""
echo "To verify installation, you can run:"
echo "  pkg-config --list-all | grep -E 'mad|a52|vorbis'"
