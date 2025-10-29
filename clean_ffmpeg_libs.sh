#!/bin/bash
# Remove problematic object files from FFmpeg libraries that cause linking errors
# These codecs are not needed for audio-only player and reference missing helper functions

FFMPEG_DIR="mplayer-trunk/ffmpeg"

echo "Cleaning FFmpeg libraries of problematic codecs..."

# List of object files to remove from libavcodec.a
ar d "$FFMPEG_DIR/libavcodec/libavcodec.a" \
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
  libavcodec/g723_1.o \
  libavcodec/g723_1_parser.o \
  libavcodec/g723_1dec.o \
  libavcodec/snow.o \
  libavcodec/snow_dwt.o \
  libavcodec/snowdec.o \
  libavcodec/snowenc.o \
  libavcodec/bsf/eia608_to_smpte436m.o \
  libavcodec/bsf/smpte436m_to_eia608.o \
  libavcodec/acelp_pitch_delay.o \
  libavcodec/celp_filters.o \
  libavcodec/mpegvideo_enc.o \
  libavcodec/mpegvideoencdsp.o \
  2>/dev/null

# List of object files to remove from libavformat.a
ar d "$FFMPEG_DIR/libavformat/libavformat.a" \
  libavformat/mccdec.o \
  libavformat/mccenc.o \
  2>/dev/null

echo "Done cleaning FFmpeg libraries"
