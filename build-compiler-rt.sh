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
BUILD_BUILTINS=TRUE
ENABLE_CFGUARD=1
CFGUARD_CFLAGS="-mguard=cf"

while [ $# -gt 0 ]; do
    if [ "$1" = "--build-sanitizers" ]; then
        SRC_DIR=..
        BUILD_SUFFIX=-sanitizers
        SANITIZERS=1
        BUILD_BUILTINS=FALSE
        # Override the default cfguard options here; this unfortunately
        # also overrides the user option if --enable-cfguard is passed
        # before --build-sanitizers (although that combination isn't
        # really intended/supported anyway).
        CFGUARD_CFLAGS=
        ENABLE_CFGUARD=
    elif [ "$1" = "--enable-cfguard" ]; then
        CFGUARD_CFLAGS="-mguard=cf"
        ENABLE_CFGUARD=1
    elif [ "$1" = "--disable-cfguard" ]; then
        CFGUARD_CFLAGS=
        ENABLE_CFGUARD=
    else
        PREFIX="$1"
    fi
    shift
done
if [ -z "$PREFIX" ]; then
    echo "$0 [--build-sanitizers] [--enable-cfguard|--disable-cfguard] dest"
    exit 1
fi
if [ -n "$SANITIZERS" ] && [ -n "$ENABLE_CFGUARD" ]; then
    echo "warning: Sanitizers may not work correctly with Control Flow Guard enabled." 1>&2
fi

mkdir -p "$PREFIX"
PREFIX="$(cd "$PREFIX" && pwd)"
export PATH="$PREFIX/bin:$PATH"

: ${ARCHS:=${TOOLCHAIN_ARCHS-i686 x86_64 armv7 aarch64}}

ANY_ARCH=$(echo $ARCHS | awk '{print $1}')
CLANG_RESOURCE_DIR="$("$PREFIX/bin/$ANY_ARCH-w64-mingw32-clang" --print-resource-dir)"

if [ ! -d llvm-project/compiler-rt ] || [ -n "$SYNC" ]; then
    CHECKOUT_ONLY=1 ./build-llvm.sh
fi

if command -v ninja >/dev/null; then
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
        i686|x86_64|aarch64)
            # Sanitizers on windows only support x86 and aarch64.
            ;;
        *)
            continue
            ;;
        esac
    fi

    [ -z "$CLEAN" ] || rm -rf build-$arch$BUILD_SUFFIX
    mkdir -p build-$arch$BUILD_SUFFIX
    cd build-$arch$BUILD_SUFFIX
    [ -n "$NO_RECONF" ] || rm -rf CMake*
    cmake \
        ${CMAKE_GENERATOR+-G} "$CMAKE_GENERATOR" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$CLANG_RESOURCE_DIR" \
        -DCMAKE_C_COMPILER=$arch-w64-mingw32-clang \
        -DCMAKE_CXX_COMPILER=$arch-w64-mingw32-clang++ \
        -DCMAKE_SYSTEM_NAME=Windows \
        -DCMAKE_AR="$PREFIX/bin/llvm-ar" \
        -DCMAKE_RANLIB="$PREFIX/bin/llvm-ranlib" \
        -DCMAKE_C_COMPILER_TARGET=$arch-windows-gnu \
        -DCOMPILER_RT_DEFAULT_TARGET_ONLY=TRUE \
        -DCOMPILER_RT_USE_BUILTINS_LIBRARY=TRUE \
        -DCOMPILER_RT_BUILD_BUILTINS=$BUILD_BUILTINS \
        -DLLVM_CONFIG_PATH="" \
        -DCMAKE_FIND_ROOT_PATH=$PREFIX/$arch-w64-mingw32 \
        -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
        -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
        -DSANITIZER_CXX_ABI=libc++ \
        -DCMAKE_C_FLAGS_INIT="$CFGUARD_CFLAGS" \
        -DCMAKE_CXX_FLAGS_INIT="$CFGUARD_CFLAGS" \
        $SRC_DIR
    $BUILDCMD ${CORES+-j$CORES}
    $BUILDCMD install
    mkdir -p "$PREFIX/$arch-w64-mingw32/bin"
    if [ -n "$SANITIZERS" ]; then
        mv "$CLANG_RESOURCE_DIR/lib/windows/"*.dll "$PREFIX/$arch-w64-mingw32/bin"
    fi
    cd ..
done
