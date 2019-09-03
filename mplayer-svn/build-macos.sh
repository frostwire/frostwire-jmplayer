#!/usr/bin/env bash
set -x
if [ -z "${OPENSSL_ROOT}" ]; then
    set +x
    clear
    echo "OPENSSL_ROOT not set."
    echo
    echo "   It should point to an openssl installation folder (not the sources)"
    echo
    echo "   try: 'export OPENSSL_ROOT=${HOME}/src/openssl'"
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

pushd mplayer-trunk/ffmpeg
./configure \
--enable-nonfree \
--enable-openssl \
--disable-programs \
--disable-bsfs \
--disable-muxers \
--disable-demuxers \
--disable-devices \
--disable-filters \
--disable-iconv \
--disable-alsa \
--disable-openal \
${ENABLED_PROTOCOLS_FLAGS} \
${DISABLED_DECODERS_FLAGS} \
${ENABLED_DECODERS_FLAGS} \
${DISABLED_ENCODERS_FLAGS}
make -j 8 #first make ffmpeg
popd

# Paths found in MacOS 10.14.6 - September 2019
MACOS_FRAMEWORKS='/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/System/Library/Frameworks'
MACOS_USR_INCLUDES='/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include'

WARNING_FLAGS='-Wno-unused-function -Wno-switch -Wno-expansion-to-defined -Wno-deprecated-declarations -Wno-shift-negative-value -Wno-pointer-sign -Wno-nullability-completeness -Wno-logical-op-parentheses -Wno-parentheses -Wdangling-else'

EXTRA_LDFLAGS='-framework CoreMedia -framework Security -framework VideoToolbox -liconv -llzma -Lffmpeg/libavutil -lavutil'
EXTRA_CFLAGS="${WARNING_FLAGS} -Os -mmacosx-version-min=10.9 -I${MACOS_FRAMEWORKS} -I${MACOS_USR_INCLUDES} -I${OPENSSL_ROOT}/include"

################################################################################
# Configure MPlayer Build
################################################################################
# TRY: --disable-autodetect
pushd mplayer-trunk
./configure \
--enable-openssl-nondistributable \
--enable-runtime-cpudetection \
--extra-cflags="${EXTRA_CFLAGS}" \
--extra-ldflags="${EXTRA_LDFLAGS}" \
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
#${ENABLED_PROTOCOLS_FLAGS} \
#${DISABLED_DECODERS_FLAGS} \
#${ENABLED_DECODERS_FLAGS} \
#${DISABLED_ENCODERS_FLAGS}

make -j 8

if [ -f "mplayer" ]; then
  echo Before Stripping
  ls -lh mplayer
  strip mplayer
  echo After Stripping, Before UPX
  ls -lh mplayer
  if [ -f "mplayer-upx" ]; then
    rm -rf mplayer-upx
  fi
  upx -9 -o mplayer-upx mplayer
  echo After UPX
  ls -lh mplayer-upx
  if [ ! -f "mplayer-upx" ]; then
    set +x
    echo "Error: could not create mplayer-upx"
  else
    cp -p mplayer-upx ../fwplayer_osx
  fi
else
  set +x
  echo "Error: build failed, mplayer executable was not created"
fi
popd
pwd
set +x
