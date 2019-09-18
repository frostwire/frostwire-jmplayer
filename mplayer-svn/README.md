# WINDOWS (CYGWIN_NT-6.1)

Make sure cygwin has the following packages installed:

```
automake, automake1.9, wget, curl, dos2unix, emacs, gcc-core, gcc-debuginfo, gcc-g++, gcc-tools-epochN-autoconf, gcc-tools-epochN-automake, gettext, make, openssh, python27, wget, yasm, jpeg, libjpeg-devel, libpng, libpng-devel, libpng-tools, libpng16, lbpng16-devel, zlib, zlib-devel, liblzma-devel, liblzma5, libiconv-devel
```

It's convenient to manage cygwin packages with something like debian's `apt`, try installing `apt-cyg`

```bash
wget https://raw.githubusercontent.com/transcode-open/apt-cyg/master/apt-cyg
chmod +x apt-cyg
mv apt-cyg /usr/local/bin
```

You will need to install (outside of cygwin)
- golang (builds the executable to prepare the encoder flags)
- git
- subversion (TortoiseSVN) [mplayer is still in subversion-land]

## EOL issues with Windows

Make sure git has been configured to use LF line endings and not CRLF ("\r\n" Windows)
```
git config --global core.autocrlf false
git config --global core.eol lf
```

For subversion make sure to copy the contents of the `dot_subversion_config` file contents into/end of your `~/.subversion/config` file.

# Build openssl

A `build-openssl.sh` script has been included for you to build fresh OpenSSL binaries and libraries

---------------------------
# macOS

```bash
brew install upx
brew install yasm
```

# Build fwplayer

Build mplayer and ffmpeg with minimum dependencies

```bash
./build.sh
```

This script will check out mplayer's code with SVN.
Its configure script will in turn clone ffmpeg with git.
The final result should be `fwplayer.exe` for Windows or `fwplayer_osx` for macOS on this folder.
