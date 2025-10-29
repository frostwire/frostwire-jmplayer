#!/usr/bin/env bash
################################################################################
# prepare_ffmpeg_flags.sh
#
# Pure bash port of prepare-ffmpeg-flags.c
# Generates FFmpeg configure flags for enabled/disabled codecs and encoders
#
# Output: Sets environment variables:
#   - DISABLED_DECODERS_FLAGS
#   - ENABLED_DECODERS_FLAGS
#   - DISABLED_ENCODERS_FLAGS
################################################################################

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

################################################################################
# Load enabled decoders from enabled-decoders.txt
################################################################################
load_enabled_decoders() {
    local decoders_file="enabled-decoders.txt"

    if [ ! -f "$decoders_file" ]; then
        echo "Error: $decoders_file not found" >&2
        return 1
    fi

    # Read file and split on whitespace into array
    # This preserves the original data without modification
    local content
    content=$(<"$decoders_file")

    # Store in global variable for other functions to use
    ENABLED_DECODERS=($content)
    return 0
}

################################################################################
# Check if a decoder is in the enabled list
################################################################################
decoder_enabled() {
    local decoder="$1"
    local -n enabled_array=$2

    for enabled in "${enabled_array[@]}"; do
        if [ "$enabled" = "$decoder" ]; then
            return 0  # Found
        fi
    done
    return 1  # Not found
}

################################################################################
# Load available decoders/encoders from FFmpeg configure
################################################################################
load_available_codecs() {
    local codec_type="$1"  # "decoders" or "encoders"

    if [ ! -d "mplayer-trunk" ]; then
        echo "Error: mplayer-trunk directory not found" >&2
        return 1
    fi

    if [ ! -d "mplayer-trunk/ffmpeg" ]; then
        echo "Error: mplayer-trunk/ffmpeg directory not found" >&2
        return 1
    fi

    # Run FFmpeg configure to list available codecs
    local output
    output=$(cd "mplayer-trunk/ffmpeg" && ./configure --list-"$codec_type" 2>/dev/null) || {
        echo "Error: Failed to query FFmpeg $codec_type" >&2
        return 1
    }

    # Parse output - split on whitespace
    local -a codecs=($output)

    # Return array as string (we'll process in calling function)
    printf '%s\n' "${codecs[@]}"
}

################################################################################
# Generate flags for enabled decoders
################################################################################
prepare_enabled_decoders_flags() {
    local -n enabled_array=$1
    local flags=""

    for decoder in "${enabled_array[@]}"; do
        if [ -n "$decoder" ]; then
            flags+="--enable-decoder=$decoder "
        fi
    done

    # Trim trailing whitespace
    flags="${flags% }"

    echo "$flags"
}

################################################################################
# Generate flags for disabled codecs
################################################################################
prepare_disabled_codecs_flags() {
    local is_encoders=$1  # true for encoders, false for decoders
    local -n enabled_array=$2
    local subject

    if [ "$is_encoders" = "true" ]; then
        subject="encoder"
    else
        subject="decoder"
    fi

    # Get list of available codecs
    local codec_type
    if [ "$is_encoders" = "true" ]; then
        codec_type="encoders"
    else
        codec_type="decoders"
    fi

    local available_output
    available_output=$(load_available_codecs "$codec_type") || return 1
    local -a available_codecs=($available_output)

    local flags=""

    for codec in "${available_codecs[@]}"; do
        if [ -z "$codec" ]; then
            continue
        fi

        # For decoders, skip if enabled; for encoders, always disable
        if [ "$is_encoders" = "false" ]; then
            if decoder_enabled "$codec" enabled_array; then
                continue
            fi
        fi

        flags+="--disable-$subject=$codec "
    done

    # Trim trailing whitespace
    flags="${flags% }"

    echo "$flags"
}

################################################################################
# Main execution
################################################################################
main() {
    # Load enabled decoders
    if ! load_enabled_decoders; then
        exit 1
    fi

    # Generate disabled decoders flags
    DISABLED_DECODERS_FLAGS=$(prepare_disabled_codecs_flags "false" ENABLED_DECODERS) || {
        echo "Error: Failed to generate disabled decoders flags" >&2
        exit 1
    }

    # Generate enabled decoders flags
    ENABLED_DECODERS_FLAGS=$(prepare_enabled_decoders_flags ENABLED_DECODERS) || {
        echo "Error: Failed to generate enabled decoders flags" >&2
        exit 1
    }

    # Generate disabled encoders flags
    DISABLED_ENCODERS_FLAGS=$(prepare_disabled_codecs_flags "true" ENABLED_DECODERS) || {
        echo "Error: Failed to generate disabled encoders flags" >&2
        exit 1
    }

    # Output in shell-evaluable format
    printf 'DISABLED_DECODERS_FLAGS="%s"\n' "$DISABLED_DECODERS_FLAGS"
    printf 'ENABLED_DECODERS_FLAGS="%s"\n' "$ENABLED_DECODERS_FLAGS"
    printf 'DISABLED_ENCODERS_FLAGS="%s"\n' "$DISABLED_ENCODERS_FLAGS"
}

main "$@"
