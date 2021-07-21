#!/bin/sh
#
# Copyright (c) 2020 Martin Storsjo
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

set -e

PREFIX="$1"
if [ -z "$PREFIX" ]; then
    echo $0 dest
    exit 1
fi

mkdir -p "$PREFIX"
PREFIX="$(cd "$PREFIX" && pwd)"

export PATH="$PREFIX/bin:$PATH"

: ${ARCHS:=${TOOLCHAIN_ARCHS-i686 x86_64 armv7 aarch64}}

if [ ! -d llvm-project/openmp ] || [ -n "$SYNC" ]; then
    CHECKOUT_ONLY=1 ./build-llvm.sh
fi

cd llvm-project/openmp

if [ -n "$(which ninja)" ]; then
    CMAKE_GENERATOR="Ninja"
    NINJA=1
    BUILDCMD=ninja
else
    : ${CORES:=$(nproc 2>/dev/null)}
    : ${CORES:=$(sysctl -n hw.ncpu 2>/dev/null)}
    : ${CORES:=4}

    case $(uname) in
    MINGW*)
        CMAKE_GENERATOR="MSYS Makefiles"
        ;;
    *)
        ;;
    esac
    BUILDCMD=make
fi

for arch in $ARCHS; do
    CMAKEFLAGS=""
    case $arch in
    i686)
        ;;
    x86_64)
        CMAKEFLAGS="$CMAKEFLAGS -DLIBOMP_ASMFLAGS=-m64"
        ;;
    *)
        # Not supported
        continue
        ;;
    esac

    [ -z "$CLEAN" ] || rm -rf build-$arch
    mkdir -p build-$arch
    cd build-$arch

    cmake \
        ${CMAKE_GENERATOR+-G} "$CMAKE_GENERATOR" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$PREFIX/$arch-w64-mingw32" \
        -DCMAKE_C_COMPILER=$arch-w64-mingw32-clang \
        -DCMAKE_CXX_COMPILER=$arch-w64-mingw32-clang++ \
        -DCMAKE_RC_COMPILER=$arch-w64-mingw32-windres \
        -DCMAKE_ASM_MASM_COMPILER=llvm-ml \
        -DCMAKE_CROSSCOMPILING=TRUE \
        -DCMAKE_SYSTEM_NAME=Windows \
        -DCMAKE_AR="$PREFIX/bin/llvm-ar" \
        -DCMAKE_RANLIB="$PREFIX/bin/llvm-ranlib" \
        -DLIBOMP_ENABLE_SHARED=TRUE \
        $CMAKEFLAGS \
        ..
    $BUILDCMD ${CORES+-j$CORES}
    $BUILDCMD install
    rm -f $PREFIX/$arch-w64-mingw32/bin/*iomp5md*
    rm -f $PREFIX/$arch-w64-mingw32/lib/*iomp5md*
    cd ..
done
