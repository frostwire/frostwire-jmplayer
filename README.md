# What is this?

FrostWire FWPlayer is a custom, audio-only mplayer build included with FrostWire for Desktop. This repository contains a comprehensive build system for creating minimal, audio-focused player binaries for multiple platforms:

- **Windows**: `fwplayer.exe` (cross-compiled from Linux for x86_64)
- **macOS**: `fwplayer_osx.x86_64` or `fwplayer_osx.arm64` (native builds)
- **Linux**: `fwplayer_linux.x86_64` or `fwplayer_linux.arm64` (native builds)

The build system is **pure bash** - no C compilation required. All scripts are portable and work across different environments without needing to compile helper utilities.

# Quick Start

The build system is managed through a simple `Makefile`. Just run:

```bash
make help                # Show all available commands
make                     # Display help (same as make help)
```

# First Time Setup

To set up your build environment (install dependencies and build OpenSSL):

```bash
make setup
```

This single command will:
1. Check for system dependencies
2. Install any missing tools (MinGW on Linux, Homebrew packages on macOS)
3. Build OpenSSL for your platform

# Building the Player

## Build for Current Platform

The simplest way - automatically detects your OS and architecture:

```bash
make build
```

This will create:
- On **Linux x86_64**: `fwplayer_linux.x86_64`
- On **Linux arm64**: `fwplayer_linux.arm64`
- On **macOS x86_64**: `fwplayer_osx.x86_64`
- On **macOS arm64**: `fwplayer_osx.arm64`

## Build for Windows (from Linux only)

To cross-compile for Windows x86_64:

```bash
make build-windows
```

Creates: `fwplayer.exe`

## Build for Specific Platforms

Explicitly build for a specific platform:

```bash
make build-linux       # Linux native build
make build-macos       # macOS native build
make build-windows     # Windows cross-compile (Linux only)
```

# Building OpenSSL

The `setup` command handles this automatically, but if you need to rebuild OpenSSL:

## Native Build

Build OpenSSL for your current platform:

```bash
make build-openssl-native
```

## Windows OpenSSL (from Linux)

For Windows cross-compilation:

```bash
make build-openssl-windows
```

# Available Commands

Run `make help` to see all available commands, or reference this list:

| Command | Description |
|---------|-------------|
| `make` or `make help` | Show this help message |
| `make setup` | First-time setup (install deps + build OpenSSL) |
| `make build` | Build for current platform |
| `make build-linux` | Build Linux player (x86_64 or arm64) |
| `make build-macos` | Build macOS player (x86_64 or arm64) |
| `make build-windows` | Build Windows player (cross-compile from Linux) |
| `make build-openssl-native` | Build OpenSSL for current platform |
| `make build-openssl-windows` | Build Windows OpenSSL (from Linux only) |
| `make install-deps` | Install system dependencies only |
| `make show-config` | Show build configuration and status |
| `make info` | Show detailed build information |
| `make clean` | Clean all build artifacts |

# Supported Audio Formats

FrostWire FWPlayer supports comprehensive audio codec support:

- **Streaming**: MP3, AAC, Opus, Vorbis
- **Lossless**: FLAC, ALAC, WavPack, TTA
- **Surround Sound**: AC3, EAC3, DTS/DCA, TrueHD
- **Legacy**: MP2, WMA v1/v2, ADPCM G.726

# Audio-Only Design

The player is optimized as an **audio-only** application with zero video support:

- **Video decoders**: None (all removed)
- **Video output drivers**: Completely disabled
- **Video-related tools**: PNG output disabled

This results in:
- Significantly smaller binaries
- Faster compilation times
- Minimal dependencies
- No video processing overhead

# Troubleshooting

## Check Your Build Environment

Before building, verify everything is configured correctly:

```bash
make show-config
```

This displays:
- Your operating system and architecture
- MPlayer and FFmpeg source status

## Platform-Specific Notes

### macOS (Apple Silicon)

UPX (binary compressor) doesn't work with arm64 binaries. On Apple Silicon (M1/M2/M3), the player will be built without UPX compression. For x86_64 Macs, UPX will automatically reduce binary size.

### Linux

All standard Linux distributions with GCC are supported. The build script automatically handles both x86_64 and arm64 architectures.

### Windows

Windows builds are only possible from Linux using the MinGW cross-compilation toolchain. The setup process handles this automatically.

# Advanced Usage

## Clean Build Artifacts

To remove all compiled files and start fresh:

```bash
make clean
```

## View Detailed Configuration

To see detailed information about your build setup:

```bash
make info
```

# Architecture Support

The build system automatically detects your host architecture and builds for it:

- **x86_64**: Supported on Linux and macOS
- **arm64**: Supported on Linux and macOS (Apple Silicon)
- **Windows**: Always builds for x86_64 when cross-compiling from Linux

# For More Information

See the individual build scripts for advanced options:
- `build_windows.sh` - Windows cross-compilation
- `build_macos.sh` - macOS native build
- `build_linux.sh` - Linux native build
- `build-openssl.sh` - OpenSSL building
- `prepare_ffmpeg_flags.sh` - FFmpeg codec flag generation

Or check the `Makefile` itself for implementation details.

# Build System Design

The build system uses **pure bash** scripting for maximum portability and no external compilation overhead:

- **No C compilation required** - The previous `prepare-ffmpeg-flags.c` has been ported to `prepare_ffmpeg_flags.sh`
- **Platform detection** - Uses standard `uname` command for OS and architecture detection
- **Portable scripts** - All scripts work across Linux, macOS, and Windows (cross-compile)
- **Zero helper utilities** - Everything is self-contained bash code

This approach ensures:
- Faster setup (no waiting for compilation)
- Better portability (works in any environment with bash)
- Easier maintenance and modification
- No platform-specific compilation issues
