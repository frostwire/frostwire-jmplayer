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
brew install pkg-config 2>/dev/null || true

echo "✓ macOS build environment ready!"
echo ""
echo "Verifying static libraries are available..."

HOMEBREW_PREFIX=$(brew --prefix)
REQUIRED_STATIC_LIBS=(
    "${HOMEBREW_PREFIX}/opt/mad/lib/libmad.a"
    "${HOMEBREW_PREFIX}/opt/a52dec/lib/liba52.a"
    "${HOMEBREW_PREFIX}/lib/libvorbis.a"
    "${HOMEBREW_PREFIX}/lib/libogg.a"
    "${HOMEBREW_PREFIX}/lib/libmp3lame.a"
)

MISSING_LIBS=0
for lib in "${REQUIRED_STATIC_LIBS[@]}"; do
    if [ -f "$lib" ]; then
        echo "✓ Found: $lib"
    else
        echo "✗ Missing: $lib"
        MISSING_LIBS=$((MISSING_LIBS + 1))
    fi
done

if [ $MISSING_LIBS -eq 0 ]; then
    echo ""
    echo "✓ All required static libraries are available for static linking!"
else
    echo ""
    echo "⚠ Warning: Some static libraries are missing. The build may fail."
    echo "Make sure to run 'make setup' to install dependencies."
fi

echo ""
echo "To verify installation, you can run:"
echo "  pkg-config --list-all | grep -E 'mad|a52|vorbis'"
