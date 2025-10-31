# FFmpeg + MPlayer Audio-Only Build Strategy

## Problem Summary
FFmpeg's selective codec building with `--disable-everything` fails because the auto-generated codec_list.c, bsf_list.c, and related registration arrays still reference ALL possible codec/format/parser/demuxer symbols, even those not compiled. This causes hundreds of undefined reference linker errors.

## Root Causes Identified
1. **FFmpeg Build System Design**: Uses monolithic registration arrays that include all symbols regardless of what's compiled
2. **FFmpeg's Thin Archive Format**: Makes it difficult to selectively exclude problematic .o files  
3. **Configure Script Limitation**: Comments inside extern declarations in parsers.c were being parsed as symbol names

## Solutions Investigated

### Solution 1: Selective Codec Enable (FAILED)
```bash
./configure \
  --disable-everything \
  --enable-decoder=aac,ac3,eac3,alac,dts,dca,flac,mp2,mp3,vorbis,opus,wavpack,tta,wmav1,wmav2,adpcm_g726,truehd \
  --enable-demuxer=wav,aiff,au,wv,ape,flac,ogg,mov,mp3,aac,ac3,mpg,m4a \
  --enable-parser=aac,dca,flac,mpegaudio,opus \
  --enable-swresample \
  --disable-programs
```
**Issue**: Generated codec_list.c still references unbuilt codecs (dirac, snow, amrnb, amrwb, g723_1, h264_oh, hevc_oh)

### Solution 2: Wrapper Object Files (ATTEMPTED)
- Idea: Replace allcodecs.o, parsers.o, etc. with minimal stubs
- **Issue**: Thin archive format in FFmpeg makes this complex

### Solution 3: Full FFmpeg Build + MPlayer-Level Disabling (RECOMMENDED)
- Build FFmpeg with all codecs enabled 
- Disable video components at MPlayer Makefile level
- **Advantage**: Works with existing FFmpeg build system
- **Trade-off**: Larger binary size (includes video codec symbols)

## Implementation - Recommended Path

### Step 1: Configure FFmpeg with Standard Settings
```bash
cd ffmpeg
./configure --disable-programs
```

### Step 2: Patch Parser Declaration Issue  
Remove problematic comment from libavcodec/parsers.c that breaks configure script:
```c
// REMOVE THIS LINE - it breaks the configure script parser:
// extern const AVCodecParser ff_ac3_parser;  // Disabled: AC3 decoder not fully built
```

### Step 3: Build FFmpeg
```bash
make -j 16
```

### Step 4: Configure MPlayer with FFmpeg
```bash
./configure --disable-mencoder --enable-openssl-nondistributable --disable-gnutls
```

### Step 5: Disable Video Codecs in MPlayer Makefile
Edit Makefile to exclude video-only components:
- vf_spp.c, vf_fspp.c, vf_qp.c (video filters with undefined symbols)
- vd_ffmpeg.c (FFmpeg video decoder)
- vf_geq.c, vf_lavc.c, vf_lavcdeint.c, vf_screenshot.c (video filters)
- demux_lavf.c (FFmpeg demuxer)
- stream_ffmpeg.c (FFmpeg streaming)
- av_sub.c (subtitle handling)

### Step 6: Build MPlayer  
```bash
make -j 16
```

## Known Issues & Workarounds

1. **AC3 Parser Configure Error**: Fixed by removing comment from parsers.c line 25

2. **Undefined Codec References**: When using selective enable, manually patch codec_list.c and bsf_list.c to remove references to uncompiled codecs

3. **Large Binary Size**: Full FFmpeg build includes unnecessary video codec symbols. Can optimize later by implementing proper selective codec build

## Testing Recommendations
After successful build:
1. Test audio formats: MP3, FLAC, AAC, Opus, Vorbis, WAV
2. Test container formats: MP4, OGG, MKV, WebM (audio)
3. Verify no video codec symbols in final binary: `nm mplayer | grep video`
4. Check binary size: `ls -lh mplayer`

## Future Improvements
1. Implement FFmpeg submodule patching to auto-remove undefined symbols
2. Consider using shared FFmpeg libraries instead of static linking
3. Explore FFmpeg's `--disable-decoder` approach with explicit enable list
