#!/usr/bin/env bash
################################################################################
# OS Detection Functions
################################################################################
# Returns 0 if not Linux, 1 if Linux (for compatibility with old scripts)
is_linux() {
    [ "$(uname -s)" = "Linux" ]
    return
}

# Returns 0 if not macOS, 1 if macOS (for compatibility with old scripts)
is_macos() {
    [ "$(uname -s)" = "Darwin" ]
    return
}

################################################################################
# Smart directory navigation - ensures we're at target directory
# Handles being in project root, mplayer-trunk, or mplayer-trunk/ffmpeg
# Usage: ensure_cd "mplayer-trunk" or ensure_cd "mplayer-trunk/ffmpeg" or ensure_cd "."
################################################################################
ensure_cd() {
    local target_dir="$1"
    local current_dir

    if [ -z "$target_dir" ]; then
        echo "Error: ensure_cd requires a target directory argument"
        return 1
    fi

    current_dir=$(pwd)

    # Normalize the target path
    target_dir=$(echo "$target_dir" | sed 's:/*$::')  # Remove trailing slashes

    # If target is ".", we want project root
    if [ "$target_dir" = "." ]; then
        target_dir=""
    fi

    # Check if we're already in the target directory
    if [ -z "$target_dir" ]; then
        # Target is project root - check if mplayer-trunk and build-functions.sh exist
        if [ -d "mplayer-trunk" ] && [ -f "build-functions.sh" ]; then
            return 0
        fi
    else
        # Check if target exists relative to current directory
        if [ -d "$target_dir" ]; then
            cd "$target_dir" || return 1
            return 0
        fi
    fi

    # We're not in the right place, figure out where we are and navigate
    # Check project structure markers
    if [ -f "build-functions.sh" ] && [ -d "mplayer-trunk" ]; then
        # We're at project root
        if [ -n "$target_dir" ]; then
            cd "$target_dir" || return 1
        fi
        return 0
    elif [ -f "binary.ver" ] || [ -f "Makefile" ] && [ -d "ffmpeg" ]; then
        # We're in mplayer-trunk
        if [ "$target_dir" = "mplayer-trunk" ]; then
            return 0
        elif [ "$target_dir" = "mplayer-trunk/ffmpeg" ] || [ "$target_dir" = "ffmpeg" ]; then
            cd ffmpeg || return 1
            return 0
        elif [ -z "$target_dir" ]; then
            # Need to go to project root
            cd .. || return 1
            return 0
        else
            cd "$target_dir" || return 1
            return 0
        fi
    elif [ -f "version.h" ] || ([ -d "libavcodec" ] && [ -d "libavformat" ]); then
        # We're in mplayer-trunk/ffmpeg
        if [ "$target_dir" = "mplayer-trunk/ffmpeg" ] || [ "$target_dir" = "ffmpeg" ]; then
            return 0
        elif [ "$target_dir" = "mplayer-trunk" ]; then
            cd .. || return 1
            return 0
        elif [ -z "$target_dir" ]; then
            # Need to go to project root
            cd ../.. || return 1
            return 0
        else
            cd "$target_dir" || return 1
            return 0
        fi
    else
        # Unknown location - try to find our way back to project root
        echo "Warning: Cannot determine current location in project structure"
        echo "Current directory: $current_dir"
        echo "Attempting to navigate to: $target_dir"
        cd "$target_dir" 2>/dev/null || return 1
    fi

    return 0
}

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
# Uses bash script to generate the ffmpeg flags to be stored in the
# following bash variables:
# DISABLED_DECODERS_FLAGS
# DISABLED_ENCODERS_FLAGS
# ENABLED_DECODERS_FLAGS
################################################################################
prepare_ffmpeg_flags() {
  if [ ! -f "prepare_ffmpeg_flags.sh" ]; then
    echo "Error: prepare_ffmpeg_flags.sh not found, can't prepare ffmpeg flags"
    echo
    exit 1
  fi

  eval "$(./prepare_ffmpeg_flags.sh)"
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
# Verify mplayer-trunk source is available
################################################################################
verify_mplayer_source() {
  if [ ! -d "mplayer-trunk" ]; then
    echo "Error: mplayer-trunk directory not found"
    echo "The complete MPlayer source code should be in the repository"
    echo "Please clone the repository with: git clone <repo-url>"
    return 1
  fi
  return 0
}

################################################################################
# Verify ffmpeg source is available
################################################################################
verify_ffmpeg_source() {
  if [ ! -d "mplayer-trunk/ffmpeg" ]; then
    echo "Error: mplayer-trunk/ffmpeg directory not found"
    echo "The complete FFmpeg source code should be in the repository"
    echo "Please clone the repository with: git clone <repo-url>"
    return 1
  fi
  return 0
}

configure_ffmpeg_windows() {
  TARGET_OS="mingw64"
  CC="x86_64-w64-mingw32-gcc"
  FFMPEG_OPTIONS="--cc=${CC} --enable-cross-compile"
  EXTRA_CFLAGS="-Os -I${OPENSSL_ROOT}/include"
  EXTRA_LDFLAGS="-L${OPENSSL_ROOT}/lib -lssl -lcrypto"
  pushd mplayer-trunk/ffmpeg
  echo "configure_ffmpeg_windows: About to ffmpeg configure for Windows"
  press_any_key
  ./configure \
      --target-os=${TARGET_OS} \
      ${FFMPEG_OPTIONS} \
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
      --disable-decoder=dirac \
      --disable-decoder=snow \
      --disable-demuxer=mcc \
      --disable-muxer=mcc \
      --disable-decoder=amrnb \
      --disable-decoder=amrwb \
      --disable-decoder=g723_1 \
      --disable-encoder=mpegvideo \
      --disable-encoder=snow \
      --disable-encoder=h264_oh \
      --disable-encoder=hevc_oh \
      ${ENABLED_PROTOCOLS_FLAGS} \
      ${DISABLED_PROTOCOLS_FLAGS} \
      ${DISABLED_DECODERS_FLAGS} \
      ${ENABLED_DECODERS_FLAGS} \
      ${DISABLED_ENCODERS_FLAGS} \
      --extra-cflags="${EXTRA_CFLAGS}" \
      --extra-ldflags="${EXTRA_LDFLAGS}"
  echo "configure_ffmpeg_windows: Finished ffmpeg configure"
  popd
  pushd mplayer-trunk/ffmpeg
}

configure_ffmpeg_macos() {
  TARGET_OS="darwin"
  EXTRA_CFLAGS="-Os"
  EXTRA_LDFLAGS=""
  pushd mplayer-trunk/ffmpeg
  echo "configure_ffmpeg_macos: About to ffmpeg configure for macOS"
  press_any_key
  ./configure \
      --target-os=${TARGET_OS} \
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
      --disable-decoder=dirac \
      --disable-decoder=snow \
      --disable-demuxer=mcc \
      --disable-muxer=mcc \
      --disable-decoder=amrnb \
      --disable-decoder=amrwb \
      --disable-decoder=g723_1 \
      --disable-encoder=mpegvideo \
      --disable-encoder=snow \
      --disable-encoder=h264_oh \
      --disable-encoder=hevc_oh \
      ${ENABLED_PROTOCOLS_FLAGS} \
      ${DISABLED_PROTOCOLS_FLAGS} \
      ${DISABLED_DECODERS_FLAGS} \
      ${ENABLED_DECODERS_FLAGS} \
      ${DISABLED_ENCODERS_FLAGS} \
      --extra-cflags="${EXTRA_CFLAGS}" \
      --extra-ldflags="${EXTRA_LDFLAGS}"
  echo "configure_ffmpeg_macos: Finished ffmpeg configure"
  popd
  pushd mplayer-trunk/ffmpeg
}

configure_ffmpeg_linux() {
  TARGET_OS="linux"
  EXTRA_CFLAGS="-Os"
  EXTRA_LDFLAGS=""
  pushd mplayer-trunk/ffmpeg
  echo "configure_ffmpeg_linux: About to ffmpeg configure for Linux"
  press_any_key
  ./configure \
      --target-os=${TARGET_OS} \
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
      --disable-decoder=dirac \
      --disable-decoder=snow \
      --disable-demuxer=mcc \
      --disable-muxer=mcc \
      --disable-decoder=amrnb \
      --disable-decoder=amrwb \
      --disable-decoder=g723_1 \
      --disable-encoder=mpegvideo \
      --disable-encoder=snow \
      --disable-encoder=h264_oh \
      --disable-encoder=hevc_oh \
      ${ENABLED_PROTOCOLS_FLAGS} \
      ${DISABLED_PROTOCOLS_FLAGS} \
      ${DISABLED_DECODERS_FLAGS} \
      ${ENABLED_DECODERS_FLAGS} \
      ${DISABLED_ENCODERS_FLAGS} \
      --extra-cflags="${EXTRA_CFLAGS}" \
      --extra-ldflags="${EXTRA_LDFLAGS}"
  echo "configure_ffmpeg_linux: Finished ffmpeg configure"
  popd
  pushd mplayer-trunk/ffmpeg
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
      --disable-decoder=dirac \
      --disable-decoder=snow \
      --disable-demuxer=mcc \
      --disable-muxer=mcc \
      --disable-decoder=amrnb \
      --disable-decoder=amrwb \
      --disable-decoder=g723_1 \
      --disable-encoder=mpegvideo \
      --disable-encoder=snow \
      --disable-encoder=h264_oh \
      --disable-encoder=hevc_oh \
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

################################################################################
# Clean up problematic FFmpeg object files from archives after build
# These codecs are not needed for audio-only player and have missing dependencies
################################################################################
cleanup_ffmpeg_problematic_objects() {
  echo "Cleaning up problematic FFmpeg object files from archives..."
  echo "Current directory: $(pwd)"

  # First, remove the object files from disk so they won't be re-archived
  echo "Removing .o files from disk..."
  rm -f libavcodec/g723_1.o \
        libavcodec/g723_1dec.o \
        libavcodec/g723_1_parser.o \
        libavcodec/amrnbdec.o \
        libavcodec/amrwbdec.o \
        libavcodec/cbrt_data.o \
        libavcodec/cbrt_data_fixed.o \
        libavcodec/diracdec.o \
        libavcodec/dirac.o \
        libavcodec/dirac_arith.o \
        libavcodec/dirac_dwt.o \
        libavcodec/dirac_parser.o \
        libavcodec/dirac_vlc.o \
        libavcodec/diracdsp.o \
        libavcodec/diractab.o \
        libavcodec/snow.o \
        libavcodec/snow_dwt.o \
        libavcodec/snowdec.o \
        libavcodec/snowenc.o \
        libavcodec/mpegvideo_enc.o \
        libavcodec/mpegvideoencdsp.o \
        libavcodec/acelp_pitch_delay.o \
        libavcodec/celp_filters.o \
        libavcodec/bsf/eia608_to_smpte436m.o \
        libavcodec/bsf/smpte436m_to_eia608.o \
        libavformat/mccdec.o \
        libavformat/mccenc.o \
        2>/dev/null || true

  # Then, remove them from the archives themselves
  if [ -f "libavcodec/libavcodec.a" ]; then
    ar d libavcodec/libavcodec.a \
      g723_1.o \
      g723_1dec.o \
      g723_1_parser.o \
      amrnbdec.o \
      amrwbdec.o \
      cbrt_data.o \
      cbrt_data_fixed.o \
      diracdec.o \
      dirac.o \
      dirac_arith.o \
      dirac_dwt.o \
      dirac_parser.o \
      dirac_vlc.o \
      diracdsp.o \
      diractab.o \
      snow.o \
      snow_dwt.o \
      snowdec.o \
      snowenc.o \
      mpegvideo_enc.o \
      mpegvideoencdsp.o \
      acelp_pitch_delay.o \
      celp_filters.o \
      2>/dev/null || true
  fi

  # Remove BSF objects from libavcodec archive
  if [ -f "libavcodec/libavcodec.a" ]; then
    ar d libavcodec/libavcodec.a \
      eia608_to_smpte436m.o \
      smpte436m_to_eia608.o \
      2>/dev/null || true
  fi

  if [ -f "libavformat/libavformat.a" ]; then
    ar d libavformat/libavformat.a \
      mccdec.o \
      mccenc.o \
      2>/dev/null || true
  fi

  echo "Done cleaning FFmpeg archives"
  return 0
}

press_any_key() {
  read -s -n 1 -p "[Press any key to continue]" && echo ""
}

strip_and_upx_final_executable() {
  local PLATFORM=$1
  local ARCH=$2

  # Determine output executable names based on platform
  case ${PLATFORM} in
    windows)
      FWPLAYER_EXEC="fwplayer.exe"
      MPLAYER_EXEC="mplayer.exe"
      MPLAYER_UPX_EXEC="mplayer-upx.exe"
      FORCE_OPTION="--force"  # Windows UPX needs force flag
      ;;
    macos)
      FWPLAYER_EXEC="fwplayer_osx.${ARCH}"
      MPLAYER_EXEC="mplayer"
      MPLAYER_UPX_EXEC="mplayer-upx"
      FORCE_OPTION=""
      ;;
    linux)
      FWPLAYER_EXEC="fwplayer_linux.${ARCH}"
      MPLAYER_EXEC="mplayer"
      MPLAYER_UPX_EXEC="mplayer-upx"
      FORCE_OPTION=""
      ;;
    *)
      echo "Error: Unknown platform ${PLATFORM}"
      return 1
      ;;
  esac

  if [ -f "${MPLAYER_EXEC}" ]; then
    echo "Before Stripping"
    ls -lh ${MPLAYER_EXEC}
    strip ${MPLAYER_EXEC}
    echo "After Stripping, Before UPX"
    ls -lh ${MPLAYER_EXEC}
    if [ -f "${MPLAYER_UPX_EXEC}" ]; then
      rm -rf ${MPLAYER_UPX_EXEC}
    fi

    # Skip UPXing for arm64 architectures
    if [ ${ARCH} == "arm64" ]; then
        cp -p ${MPLAYER_EXEC} ../${FWPLAYER_EXEC}
        echo "Skipping UPX, not compatible with arm64"
        echo "Done."
        return 0
    fi

    upx ${FORCE_OPTION} -9 -o ${MPLAYER_UPX_EXEC} ${MPLAYER_EXEC}
    echo "After UPX"
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
