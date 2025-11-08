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
# Prepare enabled protocol flags
################################################################################
prepare_enabled_protocol_flags() {
  ENABLED_PROTOCOLS_FLAGS=''
  ENABLED_PROTOCOLS=(file pipe)
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
  if [ ! -f "prepare_ffmpeg_flags.py" ]; then
    echo "Error: prepare_ffmpeg_flags.sh not found, can't prepare ffmpeg flags"
    echo
    exit 1
  fi

  eval "$(./prepare_ffmpeg_flags.py)"
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

################################################################################
# Patch FFmpeg generated list files to remove problematic codec references
# These codecs are disabled via --disable-* flags but FFmpeg's configure
# still includes them in the generated list files, causing linker errors.
# Must be called AFTER FFmpeg configure completes.
# Expects to be run from mplayer-trunk/ffmpeg directory.
################################################################################
patch_ffmpeg_generated_lists() {
  # This patches the generated codec_list files to remove references to disabled codecs
  # which would cause "undeclared identifier" errors during compilation
  echo "Patching FFmpeg generated list files to remove problematic codec references..."

  # Check we're in ffmpeg directory
  if [ ! -f "libavcodec/allcodecs.c" ]; then
    echo "ERROR: Not in FFmpeg directory. Expected libavcodec/allcodecs.c"
    return 1
  fi

  local CODECS_TO_REMOVE="ff_dirac_decoder ff_dirac_encoder ff_snow_decoder ff_snow_encoder ff_amrnb_decoder ff_amrwb_decoder ff_g723_1_decoder ff_g723_1_encoder ff_h264_oh_decoder ff_hevc_oh_decoder"
  local PARSERS_TO_REMOVE="ff_dirac_parser ff_g723_1_parser"
  local BSFS_TO_REMOVE="ff_eia608_to_smpte436m_bsf ff_smpte436m_to_eia608_bsf"

  # Patch codec_list.c - remove lines containing problematic codec references
  if [ -f "libavcodec/codec_list.c" ]; then
    for codec in $CODECS_TO_REMOVE; do
      sed -i "/&${codec},/d" libavcodec/codec_list.c
    done
  fi

  # Patch parser_list.c
  if [ -f "libavcodec/parser_list.c" ]; then
    for parser in $PARSERS_TO_REMOVE; do
      sed -i "/&${parser},/d" libavcodec/parser_list.c
    done
  fi

  # Patch bsf_list.c
  if [ -f "libavcodec/bsf_list.c" ]; then
    for bsf in $BSFS_TO_REMOVE; do
      sed -i "/&${bsf},/d" libavcodec/bsf_list.c
    done
  fi

  # Delete object files so they will be recompiled
  rm -f libavcodec/codec_list.o libavcodec/bitstream_filters.o libavcodec/parsers.o libavcodec/bsf.o libavcodec/allcodecs.o

  echo "FFmpeg generated list files patched successfully"
}

configure_ffmpeg_windows() {
  TARGET_OS="mingw64"
  CC="x86_64-w64-mingw32-gcc"
  FFMPEG_OPTIONS="--cc=${CC} --enable-cross-compile"
  EXTRA_CFLAGS="-Os"
  EXTRA_LDFLAGS=""
  echo "configure_ffmpeg_windows: About to ffmpeg configure for Windows (audio-only player)"
  press_any_key
  ./configure \
      --target-os=${TARGET_OS} \
      ${FFMPEG_OPTIONS} \
      ${ENABLED_PROTOCOLS_FLAGS} \
      ${DISABLED_DECODERS_FLAGS} \
      ${DISABLED_ENCODERS_FLAGS} \
      ${ENABLED_DECODERS_FLAGS} \
      --extra-cflags="${EXTRA_CFLAGS}" \
      --extra-ldflags="${EXTRA_LDFLAGS}"
  echo "configure_ffmpeg_windows: Finished ffmpeg configure"
}

configure_ffmpeg_macos() {
  TARGET_OS="darwin"
  EXTRA_CFLAGS="-Os"
  EXTRA_LDFLAGS=""
  echo "configure_ffmpeg_macos: About to ffmpeg configure for macOS (audio-only player)"
  press_any_key
  ./configure \
      --target-os=${TARGET_OS} \
      ${ENABLED_PROTOCOLS_FLAGS} \
      ${DISABLED_DECODERS_FLAGS} \
      ${DISABLED_ENCODERS_FLAGS} \
      ${ENABLED_DECODERS_FLAGS} \     
      --extra-cflags="${EXTRA_CFLAGS}" \
      --extra-ldflags="${EXTRA_LDFLAGS}"
  echo "configure_ffmpeg_macos: Finished ffmpeg configure"
}

configure_ffmpeg_linux() {
  TARGET_OS="linux"
  EXTRA_CFLAGS="-Os"
  EXTRA_LDFLAGS=""
  echo "configure_ffmpeg_linux: About to ffmpeg configure for Linux (audio-only player) @ $(pwd)"
  press_any_key
  ./configure \
      --target-os=${TARGET_OS} \
      --enable-static --disable-shared \
      --disable-pthreads --disable-w32threads --disable-os2threads \
      --disable-encoders --disable-muxers \
      --enable-avformat --enable-avcodec \
      --disable-avfilter \
      --disable-postproc \
      --disable-autodetect \
      --disable-doc \
      --disable-programs \
      --disable-avdevice \
      --disable-swresample \
      --disable-swscale \
      --disable-network \
      ${DISABLED_DECODERS_FLAGS} ${DISABLED_ENCODERS_FLAGS} ${ENABLED_DECODERS_FLAGS} \
      --extra-cflags="${CFLAGS}" --extra-ldflags="${LDFLAGS}"
}


################################################################################
# Clean MPlayer and FFmpeg build artifacts
# This performs a standard 'make clean' in both directories
################################################################################
clean_build_artifacts() {
  echo "Cleaning build artifacts..."

  # Save current directory
  local orig_dir=$(pwd)

  # Try to navigate to project root if not already there
  if [ ! -d "mplayer-trunk" ]; then
    if [ -d "../mplayer-trunk" ]; then
      cd ..
    elif [ -d "../../mplayer-trunk" ]; then
      cd ../..
    fi
  fi

  if [ -d "mplayer-trunk" ]; then
    echo "Cleaning mplayer-trunk..."
    cd mplayer-trunk
    make clean 2>/dev/null || true

    if [ -d "ffmpeg" ]; then
      echo "Cleaning ffmpeg..."
      cd ffmpeg
      make clean 2>/dev/null || true
      cd ..
    fi
    cd ..
  else
    echo "Warning: mplayer-trunk directory not found"
  fi

  # Return to original directory
  cd "$orig_dir"
  echo "Done cleaning build artifacts"
  return 0
}

################################################################################
# Clean FFmpeg build completely with distclean
# This is more thorough than 'make clean' and removes all configuration
# Must be called when in the ffmpeg directory
################################################################################
distclean_ffmpeg() {
  echo "Running make distclean on FFmpeg..."
  local current_dir=$(pwd)

  # Check if we're in ffmpeg directory
  if [ -f "version.h" ] || ([ -d "libavcodec" ] && [ -d "libavformat" ]); then
    make distclean 2>/dev/null || true
    echo "FFmpeg distclean complete"
  else
    echo "Error: distclean_ffmpeg must be called from within ffmpeg directory"
    return 1
  fi

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
