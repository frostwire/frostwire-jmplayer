#!/usr/bin/env python3
#################################################################################
# Author: @gubatron - November 2025
# Outputs the values of DISABLED_DECODERS_FLAGS, ENABLED_DECODERS_FLAGS
# and DISABLED_ENCODER_FLAGS so they can be evaluated as bash script variables
#
# The enabled decoder values are loaded from enabled-decoders.txt
#################################################################################

import subprocess
import os
import sys


def main():
    print(f'DISABLED_DECODERS_FLAGS="{prepare_disabled_codecs_flags(False)}"')
    print(f'ENABLED_DECODERS_FLAGS="{prepare_enabled_decoders_flags()}"')
    print(f'DISABLED_ENCODERS_FLAGS="{prepare_disabled_codecs_flags(True)}"')


def prepare_enabled_decoders_flags():
    """Generate --enable-decoder flags for all enabled decoders"""
    enabled_decoders_map = load_enabled_decoders_map()
    flags = []
    for decoder in enabled_decoders_map:
        flags.append(f"--enable-decoder={decoder}")
    return " ".join(flags)


def prepare_disabled_codecs_flags(encoders):
    """
    Returns either disabled encoders flags or disabled decoders flags.
    Disabled decoders take into consideration the enabled decoders from enabled-decoders.txt
    """
    available_codecs_array = load_available_codecs(encoders)
    subject = "encoder" if encoders else "decoder"

    enabled_decoders_map = None
    # If we're talking about decoders to disable, we need to know which decoders
    # have been marked for enablement.
    if not encoders:
        enabled_decoders_map = load_enabled_decoders_map()

    flags = []
    for codec in available_codecs_array:
        if not encoders:
            # Skip if the current decoder is enabled
            if codec in enabled_decoders_map:
                continue
        flags.append(f"--disable-{subject}={codec.strip()}")

    return " ".join(flags)


def load_enabled_decoders_map():
    """Loads decoders specified in enabled-decoders.txt as enabled"""
    try:
        with open("enabled-decoders.txt", "r") as file:
            decoders_content = file.read()
    except FileNotFoundError:
        raise FileNotFoundError("enabled-decoders.txt not found")

    decoders_arr = decoders_content.split()
    result = {}
    for decoder in decoders_arr:
        result[decoder.strip()] = True
    return result


def load_available_codecs(encoders):
    """Load available codecs by running ffmpeg configure script"""
    if not os.path.exists("mplayer-trunk"):
        raise FileNotFoundError("mplayer-trunk directory not found")

    if not os.path.exists("mplayer-trunk/ffmpeg"):
        raise FileNotFoundError("mplayer-trunk/ffmpeg directory not found")

    subject = "encoders" if encoders else "decoders"

    try:
        result = subprocess.run(
            ["sh", "configure", f"--list-{subject}"],
            cwd="mplayer-trunk/ffmpeg",
            capture_output=True,
            text=True,
            check=True
        )
        codecs = result.stdout.split()
        return codecs
    except subprocess.CalledProcessError as e:
        raise RuntimeError(f"Failed to run ffmpeg configure: {e}")


if __name__ == "__main__":
    main()
