#!/bin/sh

set -e

if [ $# -lt 1 ]; then
    echo $0 dest
    exit 1
fi
PREFIX="$1"

: ${ARCHS:=${TOOLCHAIN_ARCHS-i686 x86_64 armv7 aarch64}}

mkdir -p $PREFIX/bin
cp wrappers/*-wrapper.sh $PREFIX/bin
cd $PREFIX/bin
for arch in $ARCHS; do
    for exec in clang clang++ gcc g++; do
        ln -sf clang-target-wrapper.sh $arch-w64-mingw32-$exec
    done
    for exec in ar ranlib nm strings; do
        ln -sf llvm-$exec $arch-w64-mingw32-$exec || true
    done
    for exec in strip; do
        ln -sf $(which true) $arch-w64-mingw32-$exec
    done
    for exec in ld objdump windres dlltool; do
        ln -sf $exec-wrapper.sh $arch-w64-mingw32-$exec
    done
done
