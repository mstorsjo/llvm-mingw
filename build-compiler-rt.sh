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
else
    : ${CORES:=$(nproc 2>/dev/null)}
    : ${CORES:=$(sysctl -n hw.ncpu 2>/dev/null)}
    : ${CORES:=4}

    case $(uname) in
    MINGW*)
        CMAKE_GENERATOR="MSYS Makefiles"
        ;;
    esac
fi

cd llvm-project/compiler-rt

INSTALL_PREFIX="$CLANG_RESOURCE_DIR"

if [ -h "$CLANG_RESOURCE_DIR/include" ]; then
    # Symlink to system headers; use a staging directory in case parts
    # of the resource dir are immutable
    WORKDIR="$(mktemp -d)"; trap "rm -rf $WORKDIR" 0
    INSTALL_PREFIX="$WORKDIR/install"
fi


for arch in $ARCHS; do
    BUILDDIR="build-$arch$BUILD_SUFFIX"
    [ -z "$CLEAN" ] || rm -rf $BUILDDIR
    mkdir -p $BUILDDIR
    cd $BUILDDIR
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
        -DCMAKE_C_COMPILER_WORKS=1 \
        -DCMAKE_CXX_COMPILER_WORKS=1 \
        -DCMAKE_C_COMPILER_TARGET=$arch-w64-windows-gnu \
        -DCOMPILER_RT_DEFAULT_TARGET_ONLY=TRUE \
        -DCOMPILER_RT_USE_BUILTINS_LIBRARY=TRUE \
        -DCOMPILER_RT_BUILD_BUILTINS=$BUILD_BUILTINS \
        -DCOMPILER_RT_EXCLUDE_ATOMIC_BUILTIN=FALSE \
        -DLLVM_CONFIG_PATH="" \
        -DCMAKE_FIND_ROOT_PATH=$PREFIX/$arch-w64-mingw32 \
        -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
        -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
        -DSANITIZER_CXX_ABI=libc++ \
        -DCMAKE_C_FLAGS_INIT="$CFGUARD_CFLAGS" \
        -DCMAKE_CXX_FLAGS_INIT="$CFGUARD_CFLAGS" \
        $SRC_DIR
    cmake --build . ${CORES:+-j${CORES}}
    cmake --install . --prefix "$INSTALL_PREFIX"
    mkdir -p "$PREFIX/$arch-w64-mingw32/bin"
    if [ -n "$SANITIZERS" ]; then
        case $arch in
        aarch64)
            # asan doesn't work on aarch64 or armv7; make this clear by omitting
            # the installed files altogether.
            rm "$INSTALL_PREFIX/lib/windows/libclang_rt.asan"*aarch64*
            ;;
        armv7)
            rm "$INSTALL_PREFIX/lib/windows/libclang_rt.asan"*arm*
            ;;
        *)
            mv "$INSTALL_PREFIX/lib/windows/"*.dll "$PREFIX/$arch-w64-mingw32/bin"
            ;;
        esac
    fi
    cd ..
done

if [ "$INSTALL_PREFIX" != "$CLANG_RESOURCE_DIR" ]; then
    # symlink to system headers - skip copy
    rm -rf "$INSTALL_PREFIX/include"

    cp -r "$INSTALL_PREFIX/." $CLANG_RESOURCE_DIR
fi
