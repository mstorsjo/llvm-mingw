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

BUILD_STATIC=ON
# Shared library not supported on Windows yet per flang-rt CMakeLists.txt
BUILD_SHARED=OFF
CFGUARD_CFLAGS="-mguard=cf"

while [ $# -gt 0 ]; do
    if [ "$1" = "--disable-static" ]; then
        BUILD_STATIC=OFF
    elif [ "$1" = "--enable-static" ]; then
        BUILD_STATIC=ON
    elif [ "$1" = "--enable-cfguard" ]; then
        CFGUARD_CFLAGS="-mguard=cf"
    elif [ "$1" = "--disable-cfguard" ]; then
        CFGUARD_CFLAGS=
    else
        PREFIX="$1"
    fi
    shift
done
if [ -z "$PREFIX" ]; then
    echo "$0 [--disable-static] [--enable-cfguard|--disable-cfguard] dest"
    exit 1
fi

mkdir -p "$PREFIX"
PREFIX="$(cd "$PREFIX" && pwd)"

export PATH="$PREFIX/bin:$PATH"

# i686 and armv7 are excluded due to compile-time asserts in flang-rt
# arm64ec is excluded due to not building flang for it (unknown if it would work)
: ${ARCHS:=${TOOLCHAIN_ARCHS-x86_64 aarch64}}

CLANG_RESOURCE_DIR="$("$PREFIX/bin/clang" --print-resource-dir)"
CLANG_VERSION=$(basename "$CLANG_RESOURCE_DIR")
CLANG_MAJOR="${CLANG_VERSION%%.*}"

if [ ! -d llvm-project/flang-rt ] || [ -n "$SYNC" ]; then
    CHECKOUT_ONLY=1 ./build-llvm.sh
fi

# Find the Fortran compiler - prefer flang-new if available, otherwise use flang
if [ -x "$PREFIX/bin/flang-new" ]; then
    FLANG="$PREFIX/bin/flang-new"
elif [ -x "$PREFIX/bin/flang" ]; then
    FLANG="$PREFIX/bin/flang"
else
    echo "Error: No flang compiler found in $PREFIX/bin"
    exit 1
fi

cd llvm-project

cd runtimes

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

for arch in $ARCHS; do
    [ -z "$CLEAN" ] || rm -rf build-flang-rt-$arch
    mkdir -p build-flang-rt-$arch
    cd build-flang-rt-$arch
    [ -n "$NO_RECONF" ] || rm -rf CMake*
    cmake \
        ${CMAKE_GENERATOR+-G} "$CMAKE_GENERATOR" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$PREFIX" \
        -DCMAKE_C_COMPILER=$arch-w64-mingw32-clang \
        -DCMAKE_CXX_COMPILER=$arch-w64-mingw32-clang++ \
        -DCMAKE_Fortran_COMPILER="$FLANG" \
        -DCMAKE_C_COMPILER_TARGET=$arch-w64-windows-gnu \
        -DCMAKE_CXX_COMPILER_TARGET=$arch-w64-windows-gnu \
        -DCMAKE_Fortran_COMPILER_TARGET=$arch-w64-windows-gnu \
        -DCMAKE_SYSTEM_NAME=Windows \
        -DCMAKE_C_COMPILER_WORKS=TRUE \
        -DCMAKE_CXX_COMPILER_WORKS=TRUE \
        -DCMAKE_Fortran_COMPILER_WORKS=TRUE \
        -DCMAKE_Fortran_COMPILER_ID=LLVMFlang \
        -DCMAKE_Fortran_COMPILER_ID_RUN=TRUE \
        -DCMAKE_Fortran_SIMULATE_ID=GNU \
        -DCMAKE_Fortran_COMPILER_SUPPORTS_F90=TRUE \
        -DCMAKE_AR="$PREFIX/bin/llvm-ar" \
        -DCMAKE_RANLIB="$PREFIX/bin/llvm-ranlib" \
        -DLLVM_ENABLE_RUNTIMES="flang-rt" \
        -DLLVM_DEFAULT_TARGET_TRIPLE=$arch-w64-windows-gnu \
        -DLLVM_VERSION_MAJOR="$CLANG_MAJOR" \
        -DFLANG_RT_ENABLE_STATIC=$BUILD_STATIC \
        -DFLANG_RT_ENABLE_SHARED=$BUILD_SHARED \
        -DFLANG_RT_INCLUDE_TESTS=OFF \
        -DCMAKE_C_FLAGS_INIT="$CFGUARD_CFLAGS" \
        -DCMAKE_CXX_FLAGS_INIT="$CFGUARD_CFLAGS" \
        -DCMAKE_Fortran_FLAGS_INIT="--target=$arch-w64-windows-gnu --no-default-config" \
        ..

    cmake --build . ${CORES:+-j${CORES}}
    cmake --install .

    # Create symlink for the runtime library without the .static suffix
    # Flang looks for libflang_rt.runtime.a but we build libflang_rt.runtime.static.a
    FLANG_RT_DIR="$CLANG_RESOURCE_DIR/lib/$arch-w64-windows-gnu"
    if [ -f "$FLANG_RT_DIR/libflang_rt.runtime.static.a" ] && [ ! -e "$FLANG_RT_DIR/libflang_rt.runtime.a" ]; then
        ln -sf libflang_rt.runtime.static.a "$FLANG_RT_DIR/libflang_rt.runtime.a"
    fi

    cd ..
done
