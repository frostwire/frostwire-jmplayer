#!/usr/bin/env bash
################################################################################
# Build helper programs for the FrostWire JMPlayer build system
################################################################################
# Note: is_linux and is_macos are now implemented as shell functions
# in build-functions.sh using uname instead of compiled C programs.
# See build-functions.sh for is_linux() and is_macos() functions.

gcc -std=c11 -D_POSIX_C_SOURCE=200809L prepare-ffmpeg-flags.c -o prepare-ffmpeg-flags
