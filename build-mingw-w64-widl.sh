#!/bin/sh

set -e

if [ $# -lt 1 ]; then
    echo $0 dest
    exit 1
fi
PREFIX="$1"
# Not adding $PREFIX/bin to $PATH here, since that is expected to be
# a cross toolchain; the compiler is expected to be in $PATH already here.

: ${CORES:=4}
: ${ARCHS:=${TOOLCHAIN_ARCHS-i686 x86_64 armv7 aarch64}}

if [ -n "$HOST" ]; then
    CONFIGFLAGS="--host=$HOST"
    CROSS_NAME=$HOST-
fi

cd mingw-w64/mingw-w64-tools/widl
for arch in $ARCHS; do
    mkdir -p build-$CROSS_NAME$arch
    cd build-$CROSS_NAME$arch
    ../configure --prefix=$PREFIX --target=$arch-w64-mingw32 $CONFIGFLAGS LDFLAGS="-Wl,-s"
    make -j$CORES
    make install
    cd ..
done
