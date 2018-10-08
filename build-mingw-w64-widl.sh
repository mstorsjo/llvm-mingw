#!/bin/sh

set -e

while [ $# -gt 0 ]; do
    if [ "$1" = "--skip-triplet-prefix" ]; then
        SKIP_TRIPLET_PREFIX=1
    else
        PREFIX="$1"
    fi
    shift
done
if [ -z "$PREFIX" ]; then
    echo $0 [--skip-triplet-prefix] dest
    exit 1
fi
# Not adding $PREFIX/bin to $PATH here, since that is expected to be
# a cross toolchain; the compiler is expected to be in $PATH already here.

: ${CORES:=4}
: ${ARCHS:=${TOOLCHAIN_ARCHS-i686 x86_64 armv7 aarch64}}

if [ -n "$HOST" ]; then
    CONFIGFLAGS="$CONFIGFLAGS --host=$HOST"
    CROSS_NAME=$HOST-
    EXEEXT=.exe
fi
if [ -n "$SKIP_TRIPLET_PREFIX" ]; then
    CONFIGFLAGS="$CONFIGFLAGS --with-widl-includedir=$PREFIX/include"
    # If using the same prefix, it's enough to build one single binary.
    ALL_ARCHS="$ARCHS"
    ARCHS=x86_64
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
if [ -n "$SKIP_TRIPLET_PREFIX" ]; then
    cd $PREFIX/bin
    for arch in $ALL_ARCHS; do
        if [ "$arch" != "$ARCHS" ]; then
            ln -sf $ARCHS-w64-mingw32-widl$EXEEXT $arch-w64-mingw32-widl$EXEEXT
        fi
    done
fi
