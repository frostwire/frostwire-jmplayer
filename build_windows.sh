#!/usr/bin/env bash
################################################################################
# Author: @gubatron - September 2019
# Modified: 2025 - Refactored for Windows build (cross-compile from Linux)
# This script builds fwplayer.exe for Windows x86_64
# Audio-only player (no video support)
# We build everything with a single configure from MPlayer and it will
# subsequently build ffmpeg for us
# functions are defined in build-functions.sh
################################################################################
#set -x

source build-functions.sh

# Verify we're on x86_64 architecture
# (Ubuntu Linux is verified by Docker or the calling script)
if [ "$(uname -m)" != "x86_64" ]; then
    echo "Error: Windows cross-compilation requires x86_64 architecture"
    exit 1
fi

ARCH="x86_64"
echo "Building fwplayer.exe for Windows (${ARCH}) from Linux"
press_any_key

cd MPlayer-1.5

# Clean previous builds
make clean
make -C ffmpeg clean

CC="x86_64-w64-mingw32-gcc"
WINDRES="x86_64-w64-mingw32-windres"
WARNING_FLAGS='-Wno-error=implicit-function-declaration -Wno-unused-function -Wno-switch -Wno-expansion-to-defined -Wno-deprecated-declarations -Wno-shift-negative-value -Wno-pointer-sign -Wno-parentheses -Wdangling-else'
EXTRA_CFLAGS="${WARNING_FLAGS} -mtune=generic -fPIC -Os -I/usr/x86_64-w64-mingw32/include"
# Static linking for all audio codec libraries for portability
EXTRA_LDFLAGS="/usr/x86_64-w64-mingw32/lib/libmad.a /usr/x86_64-w64-mingw32/lib/liba52.a /usr/x86_64-w64-mingw32/lib/libvorbis.a /usr/x86_64-w64-mingw32/lib/libogg.a /usr/x86_64-w64-mingw32/lib/libmp3lame.a -lws2_32"

################################################################################
# Configure MPlayer Build for Windows (with integrated FFmpeg configuration)
################################################################################

# We now build everything with a single configure from MPlayer and it will subsequently build ffmpeg for us
./configure \
--enable-static \
--disable-shared \
--windres=${WINDRES} \
--disable-pthreads \
--target=x86_64-mingw32 \
--enable-cross-compile \
--cc=${CC} \
--enable-winsock2_h \
--disable-gnutls \
--disable-librtmp \
--disable-iconv \
--disable-mencoder \
--disable-vidix \
--disable-vidix-pcidb \
--disable-matrixview \
--disable-xss \
--disable-tga \
--disable-pnm \
--disable-md5sum \
--disable-yuv4mpeg \
--disable-png \
--disable-quartz \
--disable-vcd \
--disable-bluray \
--disable-dvdnav \
--disable-dvdread \
--disable-alsa \
--disable-ossaudio \
--disable-arts \
--disable-esd \
--disable-pulse \
--disable-jack \
--disable-openal \
--disable-nas \
--disable-sgiaudio \
--disable-sunaudio \
--disable-kai \
--disable-dart \
--disable-win32waveout \
--disable-select \
--disable-win32dll \
--disable-gl \
--disable-matrixview \
--disable-vesa \
--disable-sdl \
--disable-aa \
--disable-caca \
--disable-ggi \
--disable-ggiwmh \
--disable-direct3d \
--disable-directx \
--disable-dxr2 \
--disable-dxr3 \
--disable-v4l2 \
--disable-dvb \
--disable-mga \
--disable-xmga \
--disable-xv \
--disable-vda \
--disable-vdpau \
--disable-vm \
--disable-xinerama \
--disable-x11 \
--disable-xshape \
--disable-fbdev \
--disable-mlib \
--disable-3dfx \
--disable-tdfxfb \
--disable-s3fb \
--disable-wii \
--disable-directfb \
--disable-zr \
--disable-bl \
--disable-tdfxvid \
--disable-xvr100 \
--enable-mad \
--enable-liba52 \
--enable-libvorbis \
--enable-mp3lame \
--disable-live \
--disable-postproc \
--disable-decoder=all \
--enable-decoder=mp3 \
--enable-decoder=ac3 \
--enable-decoder=vorbis \
--extra-cflags="${EXTRA_CFLAGS}" \
--extra-ldflags="${EXTRA_LDFLAGS}"

echo "Done with ./configure, next we build @ $(pwd)"
press_any_key

make -j 8

echo "Done building, now we'll rename mplayer to its new form for FrostWire @ $(pwd)"
strip_and_upx_final_executable "windows" "x86_64"
set +x
