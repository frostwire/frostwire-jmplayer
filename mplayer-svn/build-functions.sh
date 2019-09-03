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

##############################################################################
checkout_mplayer() {
  if [ ! -d "mplayer-trunk" ]; then
      svn checkout svn://svn.mplayerhq.hu/mplayer/trunk mplayer-trunk
      # development mode
      if [ ! -d "mplayer-trunk" ]; then
        cp -pr ../mplayer-1.4-svn-clone mplayer-trunk
      fi
  fi
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
      git clone git://source.ffmpeg.org/ffmpeg.git ffmpeg
      popd
      patch mplayer-trunk/ffmpeg/libavformat/tls_openssl.c ffmpeg_tls_openssl.patch
  fi
  if [ ! -d "ffmpeg" ]; then
      set +x
      echo "Aborting: Could not git clone ffmpeg"
      popd
      return 1
  fi

  return 0
}
