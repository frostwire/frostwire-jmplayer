# What is this?

FrostWire JMPlayer is a custom, audio-only mplayer build included with FrostWire for Desktop. This repository contains platform-specific build scripts for creating minimal, audio-focused player binaries:

- **Windows**: `fwplayer.exe` (cross-compiled from Linux for x86_64)
- **macOS**: `fwplayer_osx.x86_64` or `fwplayer_osx.arm64` (native builds)
- **Linux**: `fwplayer_linux.x86_64` or `fwplayer_linux.arm64` (native builds)

# Build openssl

A `build-openssl.sh` script has been included for you to build fresh OpenSSL binaries and libraries, it's meant to work on both Ubuntu (perhaps on other Linux distros) and macOS

The resulting binaries will be stored in:

`${HOME}/src/openssl-openssl-win64-x86_64` when building for Windows in macOS
`${HOME}/src/openssl` for macOS

Note: the current .tar.gz that it downloads from openssl.org has an error in on .c file
where developers left a "return return value" at the end of a function, just remove the redundant "return" and try to rebuild again. This error should go away with further OpenSSL updates.

# Building on Linux

## Windows Build (Cross-Compilation from Linux x86_64)

Cross-compile `fwplayer.exe` for Windows x86_64 from Linux using MinGW toolchain.

### Setup

```bash
./build-os-checkers.sh
./prepare-ubuntu-environment.sh
./build-openssl.sh
export OPENSSL_ROOT=${HOME}/src/openssl-win64-x86_64
```

### Build

```bash
./build_windows.sh
```

You should have `fwplayer.exe` in the current directory when done.

## Linux Build (Native)

Build `fwplayer_linux.x86_64` or `fwplayer_linux.arm64` depending on your system architecture.

### Setup

```bash
./build-os-checkers.sh
./build-openssl.sh
export OPENSSL_ROOT=${HOME}/src/openssl
```

### Build

```bash
./build_linux.sh
```

The binary will be named `fwplayer_linux.x86_64` or `fwplayer_linux.arm64` depending on your host architecture.

---------------------------

# Building on macOS

Build native `fwplayer_osx.x86_64` or `fwplayer_osx.arm64` depending on your Mac architecture.

## Dependencies

```bash
brew install upx
brew install yasm
```

### Note on UPX for arm64 (Apple Silicon)

UPX does not work with arm64 binaries. If building on Apple Silicon (M1/M2/M3), the binary will be copied without UPX compression. For x86_64 Macs, UPX will be used to reduce binary size.

If you need to build UPX from source for arm64 support, see these notes:
https://gist.github.com/gubatron/c8ecee2d54033a0b131812324e5a7a33

## Setup

```bash
./build-os-checkers.sh
./build-openssl.sh
export OPENSSL_ROOT=${HOME}/src/openssl
```

## Build

```bash
./build_macos.sh
```

You should have `fwplayer_osx.x86_64` or `fwplayer_osx.arm64` (depending on your Mac's architecture) in the current directory when done.

---------------------------

# Audio-Only Player

FrostWire JMPlayer is optimized as an **audio-only** player with zero video support:

## What's Included

- **Video decoders**: None (all removed)
- **Video output drivers**: Completely disabled
- **Audio decoders**: Comprehensive support for 17+ audio formats

## Supported Audio Formats

- **Streaming**: MP3, AAC, Opus, Vorbis
- **Lossless**: FLAC, ALAC, WavPack, TTA
- **Surround Sound**: AC3, EAC3, DTS/DCA, TrueHD
- **Legacy**: MP2, WMA v1/v2, ADPCM G.726

## Build Configuration

All build scripts include:
- Disabled video decoders (FFmpeg configuration)
- Disabled video output drivers (MPlayer configuration)
- Disabled PNG output (to prevent video-related compilation)
- Enabled audio codecs only

This results in significantly smaller binaries and faster compilation times.