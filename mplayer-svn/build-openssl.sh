#!/usr/bin/env bash
set -x

is_linux() {
    return $(expr substr $(uname) 1 5) == "Linux"
}

OPENSSL_VERSION='1.1.1d'
OPENSSL_SRC=${HOME}/src/openssl-${OPENSSL_VERSION}
OPENSSL_PREFIX=${HOME}/src/openssl

TARGET="darwin64-x86_64-cc"
if [ is_linux ]; then
    OPENSSL_PREFIX=${HOME}/src/openssl-win32-x86
    TARGET="mingw"
    #export CC=x86_64-w64-mingw32-gcc-posix (has incompatibilities issues with ld towards the end)
    export CC=i686-w64-mingw32-gcc
fi

if [ ! -d "${OPENSSL_SRC}" ]; then
    if [ ! -f  "${OPENSSL_SRC}.tar.gz" ]; then
	pushd ${HOME}/src
	wget -4 https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz
	tar xvfz openssl-${OPENSSL_VERSION}.tar.gz
	popd
    fi
fi

if [ ! -d "${OPENSSL_SRC}" ]; then
    echo "Error: Could not find, nor fetch openssl sources at ${HOME}/src"
    exit 1
fi

if [ is_linux ]; then
    sed -i 's/if !defined(OPENSSL_SYS_WINCE) && !defined(OPENSSL_SYS_WIN32_CYGWIN)/if 0/g' ${OPENSSL_SRC}/crypto/rand/rand_win.c
    sed -i 's/if defined(_WIN32_WINNT) && _WIN32_WINNT>=0x0333/if 0/g' ${OPENSSL_SRC}/crypto/cryptlib.c
    sed -i 's/MessageBox.*//g' ${OPENSSL_SRC}/crypto/cryptlib.c
fi

if [ ! -d "${OPENSSL_PREFIX}" ]; then
    echo "Cleaning older openssl build install at ${OPENSSL_PREFIX}"
    rm -fr ${OPENSSL_PREFIX}
fi

# OPENSSL_NO_OPTS taken from jlibtorrent build script
OPENSSL_NO_OPTS="no-afalgeng no-async no-autoalginit no-autoerrinit no-capieng no-cms no-comp no-deprecated no-dgram no-dso no-dtls no-dynamic-engine no-egd no-engine no-err no-filenames no-gost no-hw no-makedepend no-multiblock no-nextprotoneg no-posix-io no-psk no-rdrand no-sctp no-shared no-sock no-srp no-srtp no-static-engine no-stdio no-threads no-ui-console no-zlib no-zlib-dynamic -fno-strict-aliasing -fvisibility=hidden -Os"

pushd ${OPENSSL_SRC}
make clean
./Configure ${TARGET} ${OPENSSL_NO_OPTS} --prefix=${OPENSSL_PREFIX}
make
make install_sw
popd
