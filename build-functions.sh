#!/usr/bin/env bash
################################################################################
# Prepare enabled protocol flags
################################################################################
prepare_enabled_protocol_flags() {
  ENABLED_PROTOCOLS_FLAGS=''
  ENABLED_PROTOCOLS=(file pipe tcp tls rtmp rtmps http https httpproxy icecast hls)
  for PROTOCOL in ${ENABLED_PROTOCOLS[@]}
  do
    ENABLED_PROTOCOLS_FLAGS+="--enable-protocol=${PROTOCOL} "
  done
  DISABLED_PROTOCOLS_FLAGS=''
  DISABLED_PROTOCOLS=(async cache concat crypto data ffrtmpcrypt ffrtmphttp ftp gopher md5 mmsh mmst prompeg rtmpe rtmpt rtmpte rtmpts rtp srtp subfile tee udp udplite)
  for PROTOCOL in ${DISABLED_PROTOCOLS[@]}
  do
    DISABLED_PROTOCOLS_FLAGS+="--disable-protocol=${PROTOCOL} "
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
    return 2
  fi
  echo "OK: ENABLED_DECODERS_FLAGS=${ENABLED_DECODERS_FLAGS}"

  if [ -z "${DISABLED_ENCODERS_FLAGS}" ]; then
    echo "Error: DISABLED_ENCODERS_FLAGS is unset"
    return 3
  fi
  echo "OK: DISABLED_ENCODERS_FLAGS=${DISABLED_ENCODERS_FLAGS}"

  if [ -z "${DISABLED_PROTOCOLS_FLAGS}" ]; then
    echo "Error: DISABLED_PROTOCOLS_FLAGS is unset"
    return 4
  fi

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
# downloads ffmpeg source code from github repo into mplayer's source folder
################################################################################
download_ffmpeg() {
  pushd mplayer-trunk
  if [ -d "ffmpeg" ]; then
    echo "download_ffmpeg: skipping, already have ffmpeg sources"
    popd
    return 0
  fi
  if [ ! -d "ffmpeg" ]; then
      git clone https://git.ffmpeg.org/ffmpeg.git ffmpeg
      #FFMPEG_VERSION="5.0.2"
      #wget -4 https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.gz
      #tar xvfz ffmpeg-${FFMPEG_VERSION}.tar.gz
      #rm ffmpeg-${FFMPEG_VERSION}.tar.gz
      #mv ffmpeg-${FFMPEG_VERSION} ffmpeg
      popd
      patch mplayer-trunk/ffmpeg/libavformat/tls_openssl.c ffmpeg_tls_openssl.patch
      pushd mplayer-trunk
  fi
  if [ ! -d "ffmpeg" ]; then
      set +x
      echo "download_ffmmpeg aborting: Could not git clone ffmpeg"
      popd
      return 1
  fi
  popd
  return 0
}

configure_ffmpeg() {
  TARGET_OS="darwin"
  LINUX_FFMPEG_OPTIONS=""
  EXTRA_CFLAGS="-Os"
  EXTRA_LDFLAGS=""
  if [ ${IS_LINUX} -eq 1 ]; then
      CC="x86_64-w64-mingw32-gcc"
      TARGET_OS="mingw64"
      LINUX_FFMPEG_OPTIONS="--cc=${CC} --enable-cross-compile"
      #-fno-reorder-functions
      EXTRA_CFLAGS="-Os -I${OPENSSL_ROOT}/include"
      EXTRA_LDFLAGS="-L${OPENSSL_ROOT}/lib -lssl -lcrypto"
  fi
  pushd mplayer-trunk/ffmpeg
  echo "configure_ffmpeg: About to ffmpeg configure"
  press_any_key
  ./configure \
      --target-os=${TARGET_OS} \
      ${LINUX_FFMPEG_OPTIONS} \
      --enable-nonfree \
      --enable-openssl \
      --enable-cross-compile \
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
      ${ENABLED_PROTOCOLS_FLAGS} \
      ${DISABLED_PROTOCOLS_FLAGS} \
      ${DISABLED_DECODERS_FLAGS} \
      ${ENABLED_DECODERS_FLAGS} \
      ${DISABLED_ENCODERS_FLAGS} \
      --extra-cflags="${EXTRA_CFLAGS}" \
      --extra-ldflags="${EXTRA_LDFLAGS}"
  echo "configure_ffmpeg: Finished ffmpeg configure"
  popd
  pushd mplayer-trunk/ffmpeg
}

press_any_key() {
  read -s -n 1 -p "[Press any key to continue]" && echo ""
}

strip_and_upx_final_executable() {
  FWPLAYER_EXEC="fwplayer_osx.${ARCH}" #we don't do linux, they can install mplayer with apt install
  MPLAYER_EXEC="mplayer"
  MPLAYER_UPX_EXEC="mplayer-upx"
  FORCE_OPTION=""

  if [ ${IS_LINUX} -eq 1 ]; then
    #CantPackException: superfluous data between sections (try --force)
    FORCE_OPTION="--force"
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

    # if it's mac with arm64 skip UPXing
    if [ ${IS_MACOS} -eq 1 ] && [ ${ARCH} == "arm64" ]; then
        cp -p ${MPLAYER_EXEC} ../${FWPLAYER_EXEC}
        echo "Skipping UPX, never works on arm64"
        echo "Done."
        return 0
    fi
    
    upx ${FORCE_OPTION} -9 -o ${MPLAYER_UPX_EXEC} ${MPLAYER_EXEC}
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
  echo "Done."
}
