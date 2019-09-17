# WINDOWS (in Ubuntu 14.04)

## Preparations (in /home/<user>/Development)

```bash
sudo apt-get update
sudo apt-get install -qq yasm
sudo apt-get install upx
sudo apt-get install -qq mingw-w64
sudo rm /usr/i686-w64-mingw32/lib/libwinpthread.dll.a
sudo rm /usr/i686-w64-mingw32/lib/libwinpthread-1.dll
sudo rm /usr/x86_64-w64-mingw32/lib/libwinpthread.dll.a
sudo rm /usr/x86_64-w64-mingw32/lib/libwinpthread-1.dll
```

## Compile OpenSSL

```
bash
wget -O openssl.tar.gz http://openssl.org/source/openssl-1.0.2h.tar.gz
tar -xzf openssl.tar.gz
sed -i 's/if !defined(OPENSSL_SYS_WINCE) && !defined(OPENSSL_SYS_WIN32_CYGWIN)/if 0/g' openssl-1.0.2h/crypto/rand/rand_win.c
cd openssl-1.0.2h/
export CC=i686-w64-mingw32-gcc
./Configure mingw --prefix=/home/<user>/Development/openssl-win32-x86
make
make install
```

## Prepare mplayer

```bash
export CC=i686-w64-mingw32-gcc
svn checkout svn://svn.mplayerhq.hu/mplayer/trunk mplayer-trunk
cp build-win32.sh mplayer-trunk
cd mplayer-trunk
./build-win32.sh
```

---------------------------
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

## Build OpenSSL

```bash
cd ~/src
wget https://www.openssl.org/source/openssl-1.1.1d.tar.gz
./Configure Cygwin-x86_64 --prefix=${HOME}/src/openssl
make
make install
```

---------------------------
# macOS

```bash
brew install upx
brew install yasm
```

Build mplayer and ffmpeg with minimum dependencies

```bash
./build-macos.sh
```

This script will check out mplayer's code with SVN.
Its configure script will in turn clone ffmpeg with git.
The final result should be fwplayer_osx on this folder.
