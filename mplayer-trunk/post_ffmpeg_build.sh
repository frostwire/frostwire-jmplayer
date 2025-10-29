#!/bin/bash
# Post-build cleanup: Remove problematic object files that reference missing symbols
# These are compiled by FFmpeg due to dependencies but not actually needed

set -e

FFM="ffmpeg"

echo "Removing problematic FFmpeg object files..."

# Remove codec object files that have unresolved dependencies
rm -f "$FFM/libavcodec/g723_1.o" \
      "$FFM/libavcodec/g723_1dec.o" \
      "$FFM/libavcodec/g723_1_parser.o" \
      "$FFM/libavcodec/amrnbdec.o" \
      "$FFM/libavcodec/amrwbdec.o" \
      "$FFM/libavcodec/cbrt_data.o" \
      "$FFM/libavcodec/cbrt_data_fixed.o" \
      "$FFM/libavcodec/diracdec.o" \
      "$FFM/libavcodec/dirac.o" \
      "$FFM/libavcodec/dirac_arith.o" \
      "$FFM/libavcodec/dirac_dwt.o" \
      "$FFM/libavcodec/dirac_parser.o" \
      "$FFM/libavcodec/dirac_vlc.o" \
      "$FFM/libavcodec/diracdsp.o" \
      "$FFM/libavcodec/diractab.o" \
      "$FFM/libavcodec/snow.o" \
      "$FFM/libavcodec/snow_dwt.o" \
      "$FFM/libavcodec/snowdec.o" \
      "$FFM/libavcodec/snowenc.o" \
      "$FFM/libavcodec/mpegvideo_enc.o" \
      "$FFM/libavcodec/mpegvideoencdsp.o" \
      "$FFM/libavcodec/acelp_pitch_delay.o" \
      "$FFM/libavcodec/celp_filters.o" \
      "$FFM/libavcodec/bsf/eia608_to_smpte436m.o" \
      "$FFM/libavcodec/bsf/smpte436m_to_eia608.o" \
      "$FFM/libavformat/mccdec.o" \
      "$FFM/libavformat/mccenc.o"

echo "Done"
