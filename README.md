# What is this?

Here we have a `build.sh` script that's meant to build the binaries for `fwplayer.exe` and `fwplayer_osx`, the custom mplayer builds included with FrostWire for Desktop.

The `build.sh` script works on macOS to make a native binary and it also works in Ubuntu to cross compile a windows 64-bit binary

# Build openssl

A `build-openssl.sh` script has been included for you to build fresh OpenSSL binaries and libraries, it's meant to work on both Ubuntu (perhaps on other Linux distros) and macOS

The resulting binaries will be stored in:

`${HOME}/src/openssl-openssl-win64-x86_64` when building for Windows in macOS
`${HOME}/src/openssl` for macOS

Note: the current .tar.gz that it downloads from openssl.org has an error in on .c file
where developers left a "return return value" at the end of a function, just remove the redundant "return" and try to rebuild again. This error should go away with further OpenSSL updates.

# Ubuntu (x86_64)

We use Linux to cross-compile `fwplayer.exe`, the windows executable.

Make sure you have all dependencies and tools necessary to cross compile the code
```bash
./build-os-checkers.sh
./prepare-ubuntu-environment.sh
./build-openssl.sh
```

Build
`./build.sh`

That's it, you should have a `fwplayer.exe` binary on this folder when the script is done

---------------------------
# macOS

```bash
brew install upx
brew install yasm
```

# building upx on mac from source
You will probably need to build ucl, here are some notes of how I managed to build on macOS with m1 (arm64) cpu
https://gist.github.com/gubatron/c8ecee2d54033a0b131812324e5a7a33

# Build fwplayer

Build mplayer and ffmpeg with minimum dependencies

```bash
./build-os-checkers.sh
./build-openssl.sh
```

Build
```
./build.sh
```

That's it, you should have a `fwplayer_osx` binary on this folder when the script is done