#!/bin/sh

set -ex

if [ $# -lt 1 ]; then
    echo $0 dest
    exit 1
fi
PREFIX="$1"
export PATH=$PREFIX/bin:$PATH

: ${ARCHS:=${TOOLCHAIN_ARCHS-i686 x86_64 armv7 aarch64}}

cd test
for arch in $ARCHS; do
    $arch-w64-mingw32-windres -i test.rc -o out.o -DVERSION=\\\"1.2.3\\\" -DVER_MAJOR=1 -DVER_MINOR=2 -DVER_REVISION=3
done
