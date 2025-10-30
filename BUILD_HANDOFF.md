# FWPlayer Build Integration - Handoff Document

## Current Status
The one-step build system is **incomplete**. FFmpeg compiles successfully but mplayer linking fails because the `--disable` flags for problematic codecs are not being respected by FFmpeg's build system.

## The Core Problem
Even though we configure FFmpeg with:
```bash
--disable-decoder=amrnb
--disable-decoder=amrwb
--disable-decoder=g723_1
--disable-decoder=dirac
--disable-decoder=snow
--disable-encoder=dirac
--disable-encoder=snow
--disable-demuxer=mcc
--disable-muxer=mcc
--disable-bsf=eia608_to_smpte436m
--disable-bsf=smpte436m_to_eia608
```

FFmpeg still compiles object files for these codecs. When mplayer links, it gets these undefined references:
- `ff_celp_math_init` (from amrnbdec, amrwbdec)
- `av_smpte_291m_anc_8bit_*` (from EIA608 BSF)
- `ff_mpegvideoencdsp_init` (from dirac/snow encoders)
- `ff_cbrt_dbl_tableinit` (from cbrt_data)
- `ff_dot_product` (from g723_1)
- And more...

## Why This Happens
FFmpeg's build system doesn't fully prevent compilation of disabled codecs. The `--disable` flags prevent them from being registered in `allcodecs.o`/`bitstream_filters.o`/`parsers.o`, but the object files are still compiled and archived.

## What Actually Worked
When manually reconfiguring FFmpeg and rebuilding (outside the one-step build), it compiled successfully because:
1. `make distclean` was run first
2. FFmpeg was reconfigured with all disable flags
3. A fresh build was done
4. Problematic .o files were manually removed from archives before relinking

## Solution Path (For Next Session)

### Option 1: Modify FFmpeg's Makefile (Recommended)
In `mplayer-trunk/ffmpeg/libavcodec/Makefile`, explicitly exclude the problematic source files:

```makefile
# Remove problematic codecs that have unresolved dependencies
OBJS-$(CONFIG_AMRNB_DECODER) :=
OBJS-$(CONFIG_AMRWB_DECODER) :=
OBJS-$(CONFIG_G723_1_DECODER) :=
OBJS-$(CONFIG_G723_1_ENCODER) :=
OBJS-$(CONFIG_DIRAC_DECODER) :=
OBJS-$(CONFIG_DIRAC_ENCODER) :=
OBJS-$(CONFIG_SNOW_DECODER) :=
OBJS-$(CONFIG_SNOW_ENCODER) :=
```

And in `mplayer-trunk/ffmpeg/libavcodec/bsf/Makefile`:
```makefile
OBJS-$(CONFIG_EIA608_TO_SMPTE436M_BSF) :=
OBJS-$(CONFIG_SMPTE436M_TO_EIA608_BSF) :=
```

### Option 2: Post-Build Archive Cleanup (Current Approach)
The cleanup function in `build-functions.sh:cleanup_ffmpeg_problematic_objects()` needs to properly remove objects from archives. This requires:
1. Detecting which objects are actually in the archive after build
2. Removing them from both disk AND archives before mplayer links
3. Handling thin archives (FFmpeg creates these by default)

## Current Build Script State

### Files to Modify in Next Session
- `build-functions.sh`: Contains all build logic and functions
- `build_linux.sh`, `build_macos.sh`, `build_windows.sh`: Platform-specific entry points
- **NO additional .sh scripts should be created** - all bash logic goes in `build-functions.sh`

### Key Functions in build-functions.sh
1. `ensure_cd()` - Smart directory navigation (working)
2. `configure_ffmpeg_*()` - FFmpeg configuration (needs fixing)
3. `cleanup_ffmpeg_problematic_objects()` - Archive cleanup (broken, needs fix)
4. `prepare_ffmpeg_flags()`, `verify_ffmpeg_flags()` - Flag generation (working)

## Immediate Next Steps for Fresh Session

1. **Diagnose exactly which .o files are in the archives after FFmpeg build**
   ```bash
   ar t mplayer-trunk/ffmpeg/libavcodec/libavcodec.a | grep -E "amrnb|g723_1|dirac|snow|eia608"
   ```

2. **One of two approaches:**

   **A) Modify FFmpeg Makefiles (Cleanest)**
   - Edit libavcodec/Makefile to exclude problematic codecs
   - Edit libavcodec/bsf/Makefile to exclude problematic BSFs
   - This prevents compilation entirely

   **B) Improve Cleanup Function (Current Path)**
   - Make cleanup robust for thin archives
   - Run cleanup BEFORE archives are linked into final archive
   - May require running cleanup immediately after FFmpeg `make`, before archive creation

3. **Test the fix**
   ```bash
   cd /home/gubatron/workspace/frostwire-fwplayer
   make clean
   make build
   ```

4. **Expected Success Indicator**
   ```
   mplayer: ELF 64-bit LSB pie executable
   ```

## Why Previous Approach Failed
- Manual archive cleanup with `ar d` doesn't work on thin archives
- `make distclean` + reconfigure wasn't being called in the one-step build
- The cleanup was happening AFTER archives were already rebuilt from objects
- Need to prevent object creation entirely (Makefile approach) OR remove objects before archive creation

## Testing Checklist for Next Session
- [ ] FFmpeg compiles without the problematic object files
- [ ] `mplayer` binary is successfully created
- [ ] Binary works: `./mplayer-trunk/mplayer` produces output
- [ ] Test on Linux (arm64 confirmed working previously)
- [ ] Consider testing on macOS and Windows (if available)

## Important Notes
- Do NOT create new shell scripts; all bash code goes in `build-functions.sh`
- The build scripts already have `make distclean` step (added in last session)
- FFmpeg's `--disable-*` flags alone are NOT sufficient
- The manual clean build that worked used direct Makefile edits and archive cleanup
