#!/usr/bin/env bash
################################################################################
# Prepare enabled protocol flags
################################################################################
prepare_enabled_protocol_flags() {
  ENABLED_PROTOCOLS_FLAGS=''
  ENABLED_PROTOCOLS=(tcp tls rtmp rtmps http https icecast hls)
  for PROTOCOL in ${ENABLED_PROTOCOLS[@]}
  do
    ENABLED_PROTOCOLS_FLAGS+="--enable-protocol=${PROTOCOL} "
  done
  return 0
}

################################################################################
# Uses golang written tool to generate the ffmpeg flags to be stored in the
# following bash variables:
# DISABLED_DECODERS_FLAGS
# DISABLED_ENCODERS_FLAGS
# ENABLED_DECODERS_FLAGS
################################################################################
prepare_ffmpeg_flags() {
  if [ ! -f "prepare-ffmpeg-flags.go" ]; then
    echo "Error: prepare-ffmpeg-flags.go not found, can't prepare ffmpeg flags"
    echo
    echo exit 1
  fi

  if [ ! -x "$(command -v go)" ]; then
    if [ ! -f "prepare-ffmpeg-flags" ]; then
      echo "Error: this script requires the 'go' command"
      echo
      exit 1
    fi
  fi

  if [ ! -f "prepare-ffmpeg-flags" ]; then
    echo "Building prepare-ffmpeg-flags..."
    go build prepare-ffmpeg-flags.go
    upx -9 -o prepare-ffmpeg-flags.upx prepare-ffmpeg-flags
    rm prepare-ffmpeg-flags
    mv prepare-ffmpeg-flags.upx prepare-ffmpeg-flags
  fi

  if [ ! -f "prepare-ffmpeg-flags" ]; then
    echo "Error: prepare-ffmpeg-flags binary not found, can't prepare ffmpeg flags"
    echo
    exit 1
  fi
  eval `./prepare-ffmpeg-flags`
  return 0
}

################################################################################
# Makes sure the following variables holding FFMpeg configurations are set
# DISABLED_DECODERS_FLAGS
# DISABLED_ENCODERS_FLAGS
# ENABLED_DECODERS_FLAGS
################################################################################
verify_ffmpeg_flags() {
  if [ -z "${DISABLED_DECODERS_FLAGS}" ]; then
    echo "Error: DISABLED_DECODERS_FLAGS is unset"
    return 1
  fi
  echo "OK: DISABLED_DECODERS_FLAGS=${DISABLED_DECODERS_FLAGS}"

  if [ -z "${ENABLED_DECODERS_FLAGS}" ]; then
    echo "Error: ENABLED_DECODERS_FLAGS is unset"
    return 3
  fi
  echo "OK: ENABLED_DECODERS_FLAGS=${ENABLED_DECODERS_FLAGS}"

  if [ -z "${DISABLED_ENCODERS_FLAGS}" ]; then
    echo "Error: DISABLED_ENCODERS_FLAGS is unset"
    return 2
  fi
  echo "OK: DISABLED_ENCODERS_FLAGS=${DISABLED_ENCODERS_FLAGS}"
  return 0
}

################################################################################
# checkout mplayer from subversion
################################################################################
checkout_mplayer() {
  if [ ! -d "mplayer-trunk" ]; then
      svn checkout svn://svn.mplayerhq.hu/mplayer/trunk mplayer-trunk
      if [ ! -d "mplayer-trunk" ]; then
        echo "checkout_mplayer: check your svn installation or network connection, could not checkout mplayer svn repo"
        return 1
      fi
  fi
  return 0
}

################################################################################
# clone ffmpeg source code from github repo into mplayer's source folder
################################################################################
clone_ffmpeg() {
  pushd mplayer-trunk
  if [ -d "ffmpeg" ]; then
    echo "clone_ffmpeg: skipping, already have ffmpeg sources"
    popd
    return 0
  fi
  if [ ! -d "ffmpeg" ]; then
      #git clone git://source.ffmpeg.org/ffmpeg.git ffmpeg
      FFMPEG_VERSION="4.2.1"      
      wget -4 https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.gz
      tar xvfz ffmpeg-${FFMPEG_VERSION}.tar.gz
      rm ffmpeg-${FFMPEG_VERSION}.tar.gz
      mv ffmpeg-${FFMPEG_VERSION} ffmpeg
      popd
      patch mplayer-trunk/ffmpeg/libavformat/tls_openssl.c ffmpeg_tls_openssl.patch
      pushd mplayer-trunk
  fi
  if [ ! -d "ffmpeg" ]; then
      set +x
      echo "Aborting: Could not git clone ffmpeg"
      popd
      return 1
  fi
  popd
  return 0
}

prepare_ffmpeg() {
  TARGET_OS="darwin"
  LINUX_FFMPEG_OPTIONS=""
  EXTRA_CFLAGS="-Os"
  if [ is_linux ]; then
      CC="x86_64-w64-mingw32-gcc"
      CC="x86_64-w64-mingw32-gcc-posix"
      CC="i686-w64-mingw32-gcc"
      TARGET_OS="mingw64"
      LINUX_FFMPEG_OPTIONS="--cc=${CC} --enable-cross-compile"
      EXTRA_CFLAGS="-Os -fno-reorder-functions"
  fi
  pushd mplayer-trunk/ffmpeg
  echo "About to configure ffmpeg"
  ./configure \
      --target-os=${TARGET_OS} \
      ${LINUX_FFMPEG_OPTIONS} \
      --enable-nonfree \
      --enable-openssl \
      --disable-doc \
      --disable-programs \
      --disable-bsfs \
      --disable-muxers \
      --disable-demuxers \
      --disable-devices \
      --disable-filters \
      --disable-iconv \
      --disable-alsa \
      --disable-openal \
      --disable-lzma \
      --extra-cflags="${EXTRA_CFLAGS}" \
      ${ENABLED_PROTOCOLS_FLAGS} \
      ${DISABLED_DECODERS_FLAGS} \
      ${ENABLED_DECODERS_FLAGS} \
      ${DISABLED_ENCODERS_FLAGS}
  echo Finished configure ffmpeg, Press [Enter] to continue...
  read
  popd
  pushd mplayer-trunk/ffmpeg
}

################################################################################
# linux helpers
###############################################################################
is_linux() {
    if [[ "$(uname -a)" == "Linux" ]]; then
      return 0
    fi
    return 1
}

strip_and_upx_final_executable() {
  FWPLAYER_EXEC="fwplayer_osx"
  MPLAYER_EXEC="mplayer"
  MPLAYER_UPX_EXEC="mplayer-upx"

  if [ is_linux ]; then
    FWPLAYER_EXEC="fwplayer.exe"
    MPLAYER_EXEC="mplayer.exe"
    MPLAYER_UPX_EXEC="mplayer-upx.exe"
  fi
  
  if [ -f "${MPLAYER_EXEC}" ]; then
    echo Before Stripping
    ls -lh ${MPLAYER_EXEC}
    strip ${MPLAYER_EXEC}
    echo After Stripping, Before UPX
    ls -lh ${MPLAYER_EXEC}
    if [ -f "${MPLAYER_UPX_EXEC}" ]; then
      rm -rf ${MPLAYER_UPX_EXEC}
    fi
    upx -9 -o ${MPLAYER_UPX_EXEC} ${MPLAYER_EXEC}
    echo After UPX
    ls -lh ${MPLAYER_UPX_EXEC}
    if [ ! -f "${MPLAYER_UPX_EXEC}" ]; then
      set +x
      echo "Error: could not create ${MPLAYER_UPX_EXEC}"
    else
      cp -p ${MPLAYER_UPX_EXEC} ../${FWPLAYER_EXEC}
    fi
  else
    set +x
    echo "Error: build failed, mplayer executable was not created"
  fi
}
