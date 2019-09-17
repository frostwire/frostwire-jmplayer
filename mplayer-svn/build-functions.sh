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

  prep_ffmpeg_flags_executable='prepare-ffmpeg-flags'
  if [ "$(expr substr $(uname -s) 1 10)" == "MINGW64_NT" ]; then
    prep_ffmpeg_flags_executable='prepare-ffmpeg-flags.exe'
  fi
  
  if [ ! -f "prepare-ffmpeg-flags" ]; then
    echo "Error: prepare-ffmpeg-flags binary not found, can't prepare ffmpeg flags"
    echo
    exit 1
  fi
  eval `./${prep_ffmpeg_flags_executable}`
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
      git clone git://source.ffmpeg.org/ffmpeg.git ffmpeg
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

################################################################################
# cygwin compatibiliy issues solved with dos2unix
################################################################################
is_cygwin() {
    return $(expr substr $(uname) 1 6) == "CYGWIN"
}

if_cygwin() {
    test is_cygwin && $@
}

dos2unix_fixes_pre_ffmpeg_configure() {
  dos2unix mplayer-trunk/configure
  dos2unix mplayer-trunk/help/*
  dos2unix mplayer-trunk/ffmpeg/configure
  dos2unix mplayer-trunk/ffmpeg/*
}

dos2unix_fixes_post_ffmpeg_configure() {
  dos2unix *
  dos2unix etc/*.conf
  dos2unix help/*.sh
}

dos2unix_fixes_post_mplayer_configure() {
  dos2unix *
  dos2unix etc/*  
  dos2unix stream/*
}

strip_and_upx_final_executable() {
	FWPLAYER_EXEC="fwplayer_osx"
	MPLAYER_EXEC="mplayer"
	MPLAYER_UPX_EXEC

	if_cygwin FWPLAYER_EXEC="fwplayer.exe"
	if_cygwin MPLAYER_EXEC="mplayer.exe"
	if_cygwin MPLAYER_UPX_EXEC="mplayer-upx.exe"

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