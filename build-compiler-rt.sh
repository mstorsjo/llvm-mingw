#!/bin/sh
#
# Copyright (c) 2018 Martin Storsjo
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

SRC_DIR=../lib/builtins
BUILD_SUFFIX=

while [ $# -gt 0 ]; do
    if [ "$1" = "--build-sanitizers" ]; then
        SRC_DIR=..
        BUILD_SUFFIX=-sanitizers
        SANITIZERS=1
    else
        PREFIX="$1"
    fi
    shift
done
if [ -z "$PREFIX" ]; then
    echo $0 [--build-sanitizers] dest
    exit 1
fi

mkdir -p "$PREFIX"
PREFIX="$(cd "$PREFIX" && pwd)"
export PATH="$PREFIX/bin:$PATH"

: ${ARCHS:=${TOOLCHAIN_ARCHS-i686 x86_64 armv7 aarch64}}

ANY_ARCH=$(echo $ARCHS | awk '{print $1}')
CLANG_VERSION=$(basename "$(dirname "$(dirname "$(dirname "$("$PREFIX/bin/$ANY_ARCH-w64-mingw32-clang" --print-libgcc-file-name -rtlib=compiler-rt)")")")")

if [ ! -d llvm-project/compiler-rt ] || [ -n "$SYNC" ]; then
    CHECKOUT_ONLY=1 ./build-llvm.sh
fi

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

cd llvm-project/compiler-rt

for arch in $ARCHS; do
    if [ -n "$SANITIZERS" ]; then
        case $arch in
        i686|x86_64)
            # Sanitizers on windows only support x86.
            ;;
        *)
            continue
            ;;
        esac
    fi

    [ -z "$CLEAN" ] || rm -rf build-$arch$BUILD_SUFFIX
    mkdir -p build-$arch$BUILD_SUFFIX
    cd build-$arch$BUILD_SUFFIX
    cmake \
        ${CMAKE_GENERATOR+-G} "$CMAKE_GENERATOR" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$PREFIX/lib/clang/$CLANG_VERSION" \
        -DCMAKE_C_COMPILER=$arch-w64-mingw32-clang \
        -DCMAKE_CXX_COMPILER=$arch-w64-mingw32-clang++ \
        -DCMAKE_SYSTEM_NAME=Windows \
        -DCMAKE_AR="$PREFIX/bin/llvm-ar" \
        -DCMAKE_RANLIB="$PREFIX/bin/llvm-ranlib" \
        -DCMAKE_C_COMPILER_TARGET=$arch-windows-gnu \
        -DCOMPILER_RT_DEFAULT_TARGET_ONLY=TRUE \
        -DCOMPILER_RT_USE_BUILTINS_LIBRARY=TRUE \
        -DSANITIZER_CXX_ABI=libc++ \
        $SRC_DIR
    $BUILDCMD ${CORES+-j$CORES}
    $BUILDCMD install
    mkdir -p "$PREFIX/$arch-w64-mingw32/bin"
    if [ -z "$SANITIZERS" ]; then
        # Building builtins only. If libunwind isn't built yet, linking of any
        # executable will still fail as we're using -unwindlib=libunwind.
        # Therefore, create a dummy libunwind.a (unless there's a real
        # libunwind installed already) to let linking succeed.
        #
        # This is a workaround to avoid needing to specify -unwindlib=none
        # for all linking until libunwind has been built. This avoids
        # needing to build libunwind right away (allowing building plain C
        # executables already now) and avoids needing to pass -unwindlib=none
        # when configuring the libunwind build.
        if [ ! -f $PREFIX/$arch-w64-mingw32/lib/libunwind.a ] && [ ! -f $PREFIX/$arch-w64-mingw32/lib/libunwind.dll.a ]; then
            # Create an archive, don't add any members.
            llvm-ar rcs $PREFIX/$arch-w64-mingw32/lib/libunwind.a
        fi
    else
        mv "$PREFIX/lib/clang/$CLANG_VERSION/lib/windows/"*.dll "$PREFIX/$arch-w64-mingw32/bin"
    fi
    cd ..
done
