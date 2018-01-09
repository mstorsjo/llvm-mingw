#!/bin/sh

set -e

if [ $# -lt 1 ]; then
    echo $0 dest
    exit 1
fi
PREFIX="$1"

: ${ARCHS:=${TOOLCHAIN_ARCHS-i686 x86_64 armv7 aarch64}}

mkdir -p $PREFIX/bin
cp wrappers/clang-target-wrapper $PREFIX/bin
cd $PREFIX/bin
for arch in $ARCHS; do
    for exec in clang clang++; do
        ln -sf clang-target-wrapper $arch-w64-mingw32-$exec
    done
done
