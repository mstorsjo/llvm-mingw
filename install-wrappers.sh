#!/bin/sh

set -e

if [ $# -lt 1 ]; then
    echo $0 dest
    exit 1
fi
PREFIX="$1"

: ${ARCHS:=${TOOLCHAIN_ARCHS-i686 x86_64 armv7 aarch64}}

mkdir -p $PREFIX/bin
cp wrappers/clang-target-wrapper.sh wrappers/objdump-wrapper.sh wrappers/ld-wrapper.sh $PREFIX/bin
cd $PREFIX/bin
for arch in $ARCHS; do
    for exec in clang clang++ gcc g++; do
        ln -sf clang-target-wrapper.sh $arch-w64-mingw32-$exec
    done
    for exec in ar ranlib nm dlltool strings; do
        ln -sf llvm-$exec $arch-w64-mingw32-$exec
    done
    for exec in strip; do
        ln -sf /bin/true $arch-w64-mingw32-$exec
    done
    for exec in ld objdump; do
        ln -sf $exec-wrapper.sh $arch-w64-mingw32-$exec
    done
done
