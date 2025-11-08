#!/usr/bin/env bash
################################################################################
# Build Functions for FrostWire FWPlayer
# Simplified utility functions for multi-platform builds
################################################################################

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
# Utility function to pause execution
################################################################################
press_any_key() {
  read -s -n 1 -p "[Press any key to continue]" && echo ""
}

################################################################################
# Strip and optionally compress final executable
# Supports: windows, macos, linux
# Usage: strip_and_upx_final_executable "platform" "arch"
################################################################################
strip_and_upx_final_executable() {
  local PLATFORM=$1
  local ARCH=$2

  # Determine output executable names based on platform
  case ${PLATFORM} in
    windows)
      FWPLAYER_EXEC="fwplayer_windows.exe"
      MPLAYER_EXEC="mplayer.exe"
      MPLAYER_UPX_EXEC="mplayer-upx.exe"
      FORCE_OPTION="--force"  # Windows UPX needs force flag
      ;;
    macos)
      FWPLAYER_EXEC="fwplayer_macos.${ARCH}"
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

    if [ "${PLATFORM}" = "macos" ]; then
      echo "Skipping UPX on macOS (not supported)"
      cp -p ${MPLAYER_EXEC} ../${FWPLAYER_EXEC}
      echo "Done."
      return 0
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
