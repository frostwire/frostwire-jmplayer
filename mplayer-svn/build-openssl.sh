#!/usr/bin/bash
set -x
OPENSSL_VERSION='1.1.1d'

if [ ! -d "${HOME}/src/openssl-${OPENSSL_VERSION}" ]; then
    if [ ! -f  "${HOME}/src/openssl-${OPENSSL_VERSION}.tar.gz" ]; then
	pushd ${HOME}/src
	wget -nv https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz
	tar xvfz openssl-${OPENSSL_VERSION}.tar.gz
	popd
    fi
fi

if [ ! -d "${HOME}/src/openssl-${OPENSSL_VERSION}" ]; then
    echo "Error: Could not find, nor fetch openssl sources at ${HOME}/src"
    exit 1
fi

if [ ! -d "${HOME}/src/openssl" ]; then
    echo "Cleaning older openssl build install at ${HOME}/src/openssl"
    rm -fr ${HOME}/src/openssl
fi

# OPENSSL_NO_OPTS taken from jlibtorrent build script
OPENSSL_NO_OPTS="no-afalgeng no-async no-autoalginit no-autoerrinit no-capieng no-cms no-comp no-deprecated no-dgram no-dso no-dtls no-dynamic-engine no-egd no-engine no-err no-filenames no-gost no-hw no-makedepend no-multiblock no-nextprotoneg no-posix-io no-psk no-rdrand no-sctp no-shared no-sock no-srp no-srtp no-static-engine no-stdio no-threads no-ui-console no-zlib no-zlib-dynamic -fno-strict-aliasing -fvisibility=hidden -Os"

pushd ${HOME}/src/openssl-${OPENSSL_VERSION}
make clean
./Configure ming ${OPENSSL_NO_OPTS} --prefix=${HOME}/src/openssl
make
make install_sw
popd
