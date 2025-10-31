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
      --disable-decoder=amrnb \
      --disable-decoder=amrwb \
      --disable-decoder=g723_1 \
      --disable-decoder=h264_oh \
      --disable-decoder=hevc_oh \
      --disable-parser=g723_1 \
      --disable-parser=dirac \
      --disable-encoder=dirac \
      --disable-encoder=snow \
      --disable-encoder=h264_oh \
      --disable-encoder=hevc_oh \
      --disable-demuxer=mcc \
      --disable-muxer=mcc \
      --disable-bsf=eia608_to_smpte436m \
      --disable-bsf=smpte436m_to_eia608 \
      ${ENABLED_PROTOCOLS_FLAGS} \
      ${DISABLED_PROTOCOLS_FLAGS} \
      ${DISABLED_DECODERS_FLAGS} \
      ${ENABLED_DECODERS_FLAGS} \
      ${DISABLED_ENCODERS_FLAGS} \
      --extra-cflags="${EXTRA_CFLAGS}" \
      --extra-ldflags="${EXTRA_LDFLAGS}"
  echo "configure_ffmpeg_windows: Finished ffmpeg configure"
  patch_ffmpeg_generated_lists
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
      --disable-decoder=amrnb \
      --disable-decoder=amrwb \
      --disable-decoder=g723_1 \
      --disable-decoder=h264_oh \
      --disable-decoder=hevc_oh \
      --disable-parser=g723_1 \
      --disable-parser=dirac \
      --disable-encoder=dirac \
      --disable-encoder=snow \
      --disable-encoder=h264_oh \
      --disable-encoder=hevc_oh \
      --disable-demuxer=mcc \
      --disable-muxer=mcc \
      --disable-bsf=eia608_to_smpte436m \
      --disable-bsf=smpte436m_to_eia608 \
      ${ENABLED_PROTOCOLS_FLAGS} \
      ${DISABLED_PROTOCOLS_FLAGS} \
      ${DISABLED_DECODERS_FLAGS} \
      ${ENABLED_DECODERS_FLAGS} \
      ${DISABLED_ENCODERS_FLAGS} \
      --extra-cflags="${EXTRA_CFLAGS}" \
      --extra-ldflags="${EXTRA_LDFLAGS}"
  echo "configure_ffmpeg_macos: Finished ffmpeg configure"
  patch_ffmpeg_generated_lists
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
      --disable-everything \
      --enable-protocol=file \
      --enable-protocol=http \
      --enable-protocol=https \
      --enable-protocol=tcp \
      --enable-protocol=tls \
      --enable-demuxer=mp3 \
      --enable-demuxer=aac \
      --enable-demuxer=flac \
      --enable-demuxer=ogg \
      --enable-demuxer=matroska \
      --enable-demuxer=mov \
      --enable-demuxer=avi \
      --enable-demuxer=mpegts \
      --enable-demuxer=mpegps \
      --enable-demuxer=wav \
      --enable-decoder=aac \
      --enable-decoder=ac3 \
      --enable-decoder=eac3 \
      --enable-decoder=alac \
      --enable-decoder=dts \
      --enable-decoder=dca \
      --enable-decoder=flac \
      --enable-decoder=mp2 \
      --enable-decoder=mp3 \
      --enable-decoder=vorbis \
      --enable-decoder=opus \
      --enable-decoder=wavpack \
      --enable-decoder=tta \
      --enable-decoder=wmav1 \
      --enable-decoder=wmav2 \
      --enable-decoder=truehd \
      --enable-parser=aac \
      --enable-parser=ac3 \
      --enable-parser=flac \
      --enable-parser=mpegaudio \
      --enable-parser=vorbis \
      --enable-parser=opus \
      --extra-cflags="${EXTRA_CFLAGS}" \
      --extra-ldflags="${EXTRA_LDFLAGS}"
  echo "configure_ffmpeg_linux: Finished ffmpeg configure"

  # Patch generated codec lists to remove problematic codecs
  patch_ffmpeg_generated_lists

  # Stay in ffmpeg directory for the patch to work
  echo "configure_ffmpeg_linux: Patching complete, exiting ffmpeg directory"
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
      --disable-decoder=amrnb \
      --disable-decoder=amrwb \
      --disable-decoder=g723_1 \
      --disable-decoder=h264_oh \
      --disable-decoder=hevc_oh \
      --disable-parser=g723_1 \
      --disable-parser=dirac \
      --disable-encoder=dirac \
      --disable-encoder=snow \
      --disable-encoder=h264_oh \
      --disable-encoder=hevc_oh \
      --disable-demuxer=mcc \
      --disable-muxer=mcc \
      --disable-bsf=eia608_to_smpte436m \
      --disable-bsf=smpte436m_to_eia608 \
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
# Must be called when in the ffmpeg directory or with ensure_cd first
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

################################################################################
# Clean up problematic FFmpeg object files after build (DEPRECATED)
# This function is kept for reference but should not be needed if Makefile
# patching works correctly
#
# Must be called from within the ffmpeg directory (after pushd mplayer-trunk/ffmpeg)
################################################################################
cleanup_ffmpeg_problematic_objects() {
  echo "Cleaning up problematic FFmpeg object files from archives..."
  local current_dir=$(pwd)
  echo "Current directory: $current_dir"

  # Verify we're in the ffmpeg directory
  if [ ! -d "libavcodec" ] || [ ! -d "libavformat" ]; then
    echo "Error: cleanup_ffmpeg_problematic_objects must be called from ffmpeg directory"
    echo "Expected to find libavcodec and libavformat subdirectories"
    return 1
  fi

  # Define lists of problematic object files with full paths (as they appear in thin archives)
  local LIBAVCODEC_PROBLEMATIC=(
    "libavcodec/g723_1.o"
    "libavcodec/g723_1dec.o"
    "libavcodec/g723_1_parser.o"
    "libavcodec/amrnbdec.o"
    "libavcodec/amrwbdec.o"
    "libavcodec/cbrt_data.o"
    "libavcodec/cbrt_data_fixed.o"
    "libavcodec/diracdec.o"
    "libavcodec/dirac.o"
    "libavcodec/dirac_arith.o"
    "libavcodec/dirac_dwt.o"
    "libavcodec/dirac_parser.o"
    "libavcodec/dirac_vlc.o"
    "libavcodec/diracdsp.o"
    "libavcodec/diractab.o"
    "libavcodec/snow.o"
    "libavcodec/snow_dwt.o"
    "libavcodec/snowdec.o"
    "libavcodec/snowenc.o"
    "libavcodec/mpegvideo_enc.o"
    "libavcodec/mpegvideoencdsp.o"
    "libavcodec/acelp_pitch_delay.o"
    "libavcodec/celp_filters.o"
    "libavcodec/bsf/eia608_to_smpte436m.o"
    "libavcodec/bsf/smpte436m_to_eia608.o"
  )

  local LIBAVFORMAT_PROBLEMATIC=(
    "libavformat/mccdec.o"
    "libavformat/mccenc.o"
  )

  # Clean libavcodec.a (convert thin archive to regular archive, remove problematic objects)
  if [ -f "libavcodec/libavcodec.a" ]; then
    echo "Processing libavcodec.a (thin archive)..."

    # Step 1: Extract all members from thin archive
    echo "  Extracting all objects from thin archive..."
    local temp_dir="$(mktemp -d)"
    local saved_dir="$(pwd)"
    cd "$temp_dir"
    ar x "${saved_dir}/libavcodec/libavcodec.a"

    # Step 2: Remove problematic object files
    echo "  Removing problematic object files..."
    for obj in "${LIBAVCODEC_PROBLEMATIC[@]}"; do
      rm -f "$(basename "$obj")" 2>/dev/null || true
    done

    # Step 3: Create a new regular (non-thin) archive
    echo "  Creating new archive without problematic objects..."
    ar rcs "${saved_dir}/libavcodec/libavcodec.a.new" *.o

    # Step 4: Replace old archive with new one
    mv "${saved_dir}/libavcodec/libavcodec.a.new" "${saved_dir}/libavcodec/libavcodec.a"

    # Cleanup temp directory
    cd "$saved_dir"
    rm -rf "$temp_dir"
    echo "  libavcodec.a cleaned and converted to regular archive"
  fi

  # Clean libavformat.a (convert thin archive to regular archive, remove problematic objects)
  if [ -f "libavformat/libavformat.a" ]; then
    echo "Processing libavformat.a (thin archive)..."

    # Step 1: Extract all members from thin archive
    echo "  Extracting all objects from thin archive..."
    local temp_dir="$(mktemp -d)"
    local saved_dir="$(pwd)"
    cd "$temp_dir"
    ar x "${saved_dir}/libavformat/libavformat.a"

    # Step 2: Remove problematic object files
    echo "  Removing problematic object files..."
    for obj in "${LIBAVFORMAT_PROBLEMATIC[@]}"; do
      rm -f "$(basename "$obj")" 2>/dev/null || true
    done

    # Step 3: Create a new regular (non-thin) archive
    echo "  Creating new archive without problematic objects..."
    ar rcs "${saved_dir}/libavformat/libavformat.a.new" *.o

    # Step 4: Replace old archive with new one
    mv "${saved_dir}/libavformat/libavformat.a.new" "${saved_dir}/libavformat/libavformat.a"

    # Cleanup temp directory
    cd "$saved_dir"
    rm -rf "$temp_dir"
    echo "  libavformat.a cleaned and converted to regular archive"
  fi

  echo "Done cleaning problematic FFmpeg object files"
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
