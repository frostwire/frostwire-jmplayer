# FWPlayer One-Step Build

## Quick Start

```bash
export OPENSSL_ROOT=$HOME/src/openssl
bash build_linux.sh      # Linux native build
bash build_macos.sh      # macOS native build
bash build_windows.sh    # Windows cross-compile (from Linux)
```

## What Happens

1. **FFmpeg Compilation**
   - Uses `--disable-everything` for minimal build
   - Explicitly enables ONLY popular codecs (mp3, aac, flac, vorbis, opus, etc.)
   - Builds static libraries with OpenSSL support
   - No obscure/problematic codecs included

2. **MPlayer Linking**
   - Links against compiled FFmpeg libraries
   - Strips and UPX compresses final binary
   - Output: `fwplayer_linux`, `fwplayer_osx`, or `fwplayer.exe`

## Codec Strategy

**Enabled Decoders** (popular torrent/internet formats):
- **Audio**: mp3, aac (m4a), flac, vorbis (ogg), opus, ac3, eac3, dts, truehd, wmav1, wmav2, wavpack, tta, alac
- **Protocols**: file, http, https, tcp, tls
- **Demuxers**: mp3, aac, flac, ogg, matroska (mkv), mov (mp4), avi, mpegts, mpegps, wav

This whitelist approach avoids obscure codecs that cause build issues.

## Build Output

- **Linux**: `mplayer-trunk/mplayer` → compressed as `fwplayer_linux.arm64` or `fwplayer_linux.x86_64`
- **macOS**: `mplayer-trunk/mplayer` → compressed as `fwplayer_osx.arm64` or `fwplayer_osx.x86_64`
- **Windows**: `mplayer-trunk/mplayer.exe` → compressed as `fwplayer.exe`

## Key Features

- ✅ Single command build process
- ✅ Smart directory navigation (ensure_cd function)
- ✅ Automatic cleanup of problematic FFmpeg objects
- ✅ Cross-platform support (Linux, macOS, Windows)
- ✅ OpenSSL integration for HTTPS support
- ✅ Binary compression with UPX
