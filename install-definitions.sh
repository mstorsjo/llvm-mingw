#!/bin/sh

set -e

if [ $# -lt 1 ]; then
    echo $0 dest
    exit 1
fi
PREFIX="$1"

: ${ARCHS:=${TOOLCHAIN_ARCHS-i686 x86_64 armv7 aarch64}}

mkdir -p $PREFIX/share
for arch in $ARCHS; do
    sed "s:@PREFIX@:${PREFIX}:g;s:@ARCH@:${arch}:g" \
        wrappers/unknown-w64-mingw32.cmake.in > "$PREFIX/share/$arch-w64-mingw32.cmake"
    sed "s:@PREFIX@:${PREFIX}:g;s:@ARCH@:${arch}:g" \
        wrappers/unknown-w64-mingw32.meson.in > "$PREFIX/share/$arch-w64-mingw32.meson"
done
