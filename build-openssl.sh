#!/usr/bin/env bash
################################################################################
# Author: @gubatron - September 2019 - January 2023
# Modified: 2025 - Platform-specific OpenSSL builds
################################################################################
# This script builds OpenSSL for the native platform:
# - On macOS: builds OpenSSL for macOS
# - On Linux: builds OpenSSL for Linux (native)
#
# To build Windows OpenSSL from Linux for cross-compilation:
#   BUILD_FOR_WINDOWS=1 ./build-openssl.sh
#
# set -x

source build-functions.sh

OPENSSL_VERSION='3.5.3'
OPENSSL_SRC=${HOME}/src/openssl-${OPENSSL_VERSION}
OPENSSL_PREFIX=${HOME}/src/openssl

if [ ! -d "${HOME}/src" ]; then
    mkdir ${HOME}/src
fi

ARCH=`arch`
TARGET="darwin64-${ARCH}-cc"

# Normalize architecture names
if [ ${ARCH} == "i386" ]; then
    ARCH=x86_64
fi

if [ ${ARCH} == "aarch64" ]; then
    ARCH=arm64
fi

if is_linux; then
    # Check if building for Windows (cross-compilation)
    if [ "${BUILD_FOR_WINDOWS}" = "1" ]; then
        OPENSSL_PREFIX=${HOME}/src/openssl-win64-x86_64
        TARGET="mingw64"
        export CC=x86_64-w64-mingw32-gcc
    else
        # Native Linux build
        OPENSSL_PREFIX=${HOME}/src/openssl
        # Set appropriate OpenSSL target for Linux architecture
        if [ ${ARCH} == "arm64" ]; then
            TARGET="linux-aarch64"
        else
            TARGET="linux-x86_64"
        fi
        # For Linux native builds, don't set CC to use system compiler
        unset CC
    fi
fi

if [ ! -d "${OPENSSL_SRC}" ]; then
    if [ ! -f  "${OPENSSL_SRC}.tar.gz" ]; then
	pushd ${HOME}/src
	echo wget -4 https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz
        wget -4 https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz
	tar xvfz openssl-${OPENSSL_VERSION}.tar.gz
	popd
    fi
fi

if [ ! -d "${OPENSSL_SRC}" ]; then
    echo "Error: Could not find, nor fetch openssl sources at ${HOME}/src"
    exit 1
fi

# Only apply Windows-specific sed patches when cross-compiling for Windows from Linux
if is_linux && [ "${BUILD_FOR_WINDOWS}" = "1" ]; then
    sed -i 's/if !defined(OPENSSL_SYS_WINCE) && !defined(OPENSSL_SYS_WIN32_CYGWIN)/if 0/g' ${OPENSSL_SRC}/crypto/rand/rand_win.c
    sed -i 's/if defined(_WIN32_WINNT) && _WIN32_WINNT>=0x0333/if 0/g' ${OPENSSL_SRC}/crypto/cryptlib.c
    sed -i 's/MessageBox.*//g' ${OPENSSL_SRC}/crypto/cryptlib.c
fi

if [ ! -d "${OPENSSL_PREFIX}" ]; then
    echo "Cleaning older openssl build install at ${OPENSSL_PREFIX}"
    rm -fr ${OPENSSL_PREFIX}
fi

# OPENSSL_NO_OPTS taken from jlibtorrent build script
OPENSSL_NO_OPTS="no-idea no-mdc2 no-rc5 no-afalgeng no-async no-autoalginit no-autoerrinit no-capieng no-cms no-comp no-deprecated no-dgram no-dso no-dtls no-dynamic-engine no-egd no-engine no-err no-filenames no-gost no-hw no-makedepend no-multiblock no-nextprotoneg no-posix-io no-psk no-rdrand no-sctp no-shared no-sock no-srp no-srtp no-static-engine no-stdio no-threads no-ui-console no-zlib no-zlib-dynamic -fno-strict-aliasing -fvisibility=hidden -Os"

pushd ${OPENSSL_SRC}
make clean 
./Configure ${TARGET} ${OPENSSL_NO_OPTS} --prefix=${OPENSSL_PREFIX}
read -s -n 1 -p "[Press any key to continue]"
make
make install_sw
popd

export OPENSSL_ROOT=${OPENSSL_PREFIX}
