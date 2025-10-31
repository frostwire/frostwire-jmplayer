# FFmpeg Build Issues - Audio-Only MPlayer

## Summary
The FFmpeg build for audio-only mplayer-trunk is incomplete with partial codec/format/demuxer implementations, causing extensive undefined reference linker errors.

## Root Cause
FFmpeg was configured with `--enable-decoder=<audio-only-codecs>` and selective `--disable-decoder=<video-codecs>`, but the build system still generates registration arrays (allcodecs.c, allformats.c, parser_list.c, bitstream_filters.c) that reference ALL possible codec/format/parser/demuxer symbols, even those not compiled.

### Problematic Files
- `ffmpeg/libavcodec/allcodecs.o` - References ~500+ undefined codec symbols
- `ffmpeg/libavcodec/parsers.o` - References ~70 undefined parser symbols
- `ffmpeg/libavcodec/bitstream_filters.o` - References ~30 undefined BSF symbols
- `ffmpeg/libavformat/allformats.o` - References hundreds of muxer/demuxer symbols
- `ffmpeg/libavformat/protocols.o` - References all protocol implementations

## Modifications Made

### 1. MPlayer Makefile Changes
- Disabled video-only FFmpeg filters (vf_spp.c, vf_fspp.c, vf_qp.c)
- Disabled video decoders (vd_ffmpeg.c)
- Disabled video filters (vf_geq.c, vf_lavc.c, vf_lavcdeint.c, vf_screenshot.c)
- Disabled libavformat demuxer (demux_lavf.c)
- Disabled stream FFmpeg support (stream_ffmpeg.c)
- Disabled subtitle handling (av_sub.c)

### 2. FFmpeg Configuration Changes
- Commented out AC3 parser registration in `parsers.c` and `parser_list.c`
- Updated MPlayer Makefile to exclude libavformat from linking
- Reduced FFMPEGPARTS to only libavcodec, libswscale, libswresample, libavutil

## Current Status
**BUILD STILL FAILING** - Too many undefined symbols in:
- parsers.o (audio parsers not built)
- bitstream_filters.o (all BSFs not built)
- allcodecs.o (video codecs not built)

## Required Solutions (in priority order)

### Option 1: Rebuild FFmpeg with Proper Minimal Configuration (RECOMMENDED)
```bash
cd ffmpeg
./configure \
  --enable-shared \
  --disable-everything \
  --enable-decoder=aac,ac3,eac3,alac,dts,dca,flac,mp2,mp3,vorbis,opus,wavpack,tta,wmav1,wmav2,adpcm_g726,truehd \
  --enable-encoder=none \
  --enable-demuxer=wav,aiff,au,wv,ape,flac,ogg,mov,mp3,aac,ac3,mpg,m4a \
  --enable-parser=aac,dca,flac,mpegaudio,opus \
  --enable-libswresample \
  --enable-swresample \
  --disable-programs
make clean
make install
```

### Option 2: Create Wrapper Object Files
Extract allcodecs.o, parsers.o, bitstream_filters.o from archive and replace with minimal stubs providing empty arrays.

### Option 3: Use Shared FFmpeg Libraries
If system FFmpeg is available, build MPlayer against shared libraries instead of static archives.

## FFmpeg Codec Status
Attempted to enable for audio-only use:
- ✅ Enabled: AAC, AC3, E-AC3, ALAC, DTS, DCA, FLAC, MP2, MP3, Vorbis, Opus, WavPack, TTA, WMAv1/2, ADPCM-G726, TrueHD
- ❌ Parser for AC3 disabled - symbols not available (AC3 table symbols missing)
- ❌ All format muxers/demuxers not built - thousands of undefined references

## Key Insights
1. FFmpeg's codec registry system (allcodecs.c, allformats.c) is monolithic and doesn't support partial builds well
2. Audio-only builds still reference video codec/format symbols through registration arrays
3. The thin archive format (FFmpeg uses) makes it hard to selectively exclude problematic .o files
4. MPlayer's conditional compilation for FFmpeg audio decoders needs more aggressive disabling

## Testing Recommendations
After implementing a solution:
1. Test audio decoding with various codecs (AAC, MP3, FLAC, Opus, etc.)
2. Test streaming formats (WAV, OGG, M4A, MP3)
3. Verify no video rendering code is included in final binary
4. Check binary size to ensure unnecessary code excluded

## References
- FFmpeg Configure: `./ffmpeg/configure --help`
- Build Log: `/home/gubatron/workspace/frostwire-fwplayer/build_SUCCESS.log`
- MPlayer Trunk: `/home/gubatron/workspace/frostwire-fwplayer/mplayer-trunk`
