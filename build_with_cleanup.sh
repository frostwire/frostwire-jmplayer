#!/bin/bash
# Build script that cleans up problematic FFmpeg object files before linking

set -e

echo "Building FrostWire FWPlayer..."

cd mplayer-trunk

# Build FFmpeg
echo "Building FFmpeg..."
cd ffmpeg
make -j 8
cd ..

# Clean up problematic object files that cause linking errors
echo "Cleaning up problematic FFmpeg object files..."
./post_ffmpeg_build.sh

# Build mplayer
echo "Building mplayer..."
make -j 8

echo "Build complete!"
