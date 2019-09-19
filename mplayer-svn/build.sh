#!/usr/bin/env bash
################################################################################
# Author: @gubatron - September 2019
# functions are defined in build-functions.sh
# ffmpeg codec flag related variables are generated by prepare-ffmpeg-flags.go
# as output strings which are evaluated by prepare_ffmpeg_flags
################################################################################

set -x
if [ -z "${OPENSSL_ROOT}" ]; then
    set +x
    clear
    echo "OPENSSL_ROOT not set."
    echo
    echo "   It should point to an openssl installation folder (not the sources)"
    echo
    echo "   try: 'export OPENSSL_ROOT=${HOME}/src/openssl'           (mac, to build for mac)"
    echo "    or: 'export OPENSSL_ROOT=${HOME}/src/openssl-win32-x86' (ubuntu, to build for windows)"
    echo
    exit 1
fi

export PKG_CONFIG_PATH="${OPENSSL_ROOT}/lib/pkgconfig"
source build-functions.sh

prepare_enabled_protocol_flags
if [ -z "${ENABLED_PROTOCOLS_FLAGS}" ]; then
  echo "Error: ENABLED_PROTOCOLS_FLAGS is unset"
  echo ${ENABLED_PROTOCOLS_FLAGS}
  exit 1
fi

checkout_mplayer
if [ ! -d "mplayer-trunk" ]; then
  echo "Error: mplayer-trunk not checked out, nothing to build"
  echo ""
  exit 1
fi

# Check out ffmpeg inside mplayer folder
clone_ffmpeg
if [ ! -d "mplayer-trunk/ffmpeg" ]; then
  echo "Error: can't find 'ffmpeg' folder inside mplayer-trunk/, can't prepare codec flags without it"
  echo
  exit 1
fi

prepare_ffmpeg_flags
verify_ffmpeg_flags || exit 1

# First we need to build ffmpeg
prepare_ffmpeg
make -j 8
popd

# Paths found in MacOS 10.14.6 - September 2019
MACOS_FRAMEWORKS='/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/System/Library/Frameworks'
MACOS_USR_INCLUDES='/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include'

WARNING_FLAGS='-Wno-unused-function -Wno-switch -Wno-expansion-to-defined -Wno-deprecated-declarations -Wno-shift-negative-value -Wno-pointer-sign -Wno-nullability-completeness -Wno-logical-op-parentheses -Wno-parentheses -Wdangling-else'

EXTRA_LDFLAGS='-framework CoreMedia -framework Security -framework VideoToolbox -liconv -Lffmpeg/libavutil -lavutil -L${OPENSSL_ROOT}/lib -lssl -lcrypto'
EXTRA_CFLAGS="${WARNING_FLAGS} -Os -mmacosx-version-min=10.9 -I${MACOS_FRAMEWORKS} -I${MACOS_USR_INCLUDES} -I${OPENSSL_ROOT}/include"
CONFIG_LINUX_OPTS=''

if [ is_linux ]; then
  CC="x86_64-w64-mingw32-gcc"
  CC="x86_64-w64-mingw32-gcc-posix"
  CC="i686-w64-mingw32-gcc"
  WARNING_FLAGS='-Wno-error=implicit-function-declaration -Wno-unused-function -Wno-switch -Wno-expansion-to-defined -Wno-deprecated-declarations -Wno-shift-negative-value -Wno-pointer-sign -Wno-parentheses -Wdangling-else'
  #--enable-runtime-cpudetection --enable-static 
  CONFIG_LINUX_OPTS='--windres=i686-w64-mingw32-windres --disable-pthreads --target=x86_64 --enable-cross-compile --host-cc=x86_64-w64-mingw32-gcc'
  EXTRA_LDFLAGS="-L${OPENSSL_ROOT}/lib -lssl -lcrypto -Lffmpeg/libavutil -lavutil"
  EXTRA_CFLAGS="${WARNING_FLAGS} -Os -I/usr/i686-w64-mingw32/include -I${OPENSSL_ROOT}/include"
fi

################################################################################
# Configure MPlayer Build
################################################################################
pushd mplayer-trunk
./configure \
--enable-openssl-nondistributable \
--extra-cflags="${EXTRA_CFLAGS}" \
--extra-ldflags="${EXTRA_LDFLAGS}" \
${CONFIG_LINUX_OPTS} \
--disable-gnutls \
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
--disable-win32dll

make -j 8

strip_and_upx_final_executable

popd
pwd
set +x
