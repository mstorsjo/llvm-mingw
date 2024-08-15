#!/bin/sh
#
# Copyright (c) 2024 Martin Storsjo
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

set -ex

if [ $# -lt 1 ]; then
    echo $0 toolchain
    exit 1
fi
PREFIX="$1"
PREFIX="$(cd "$PREFIX" && pwd)"

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

: ${ARCHS:=${TOOLCHAIN_ARCHS-i686 x86_64 armv7 aarch64 arm64ec}}

case $(uname) in
MINGW*|MSYS*)
    NATIVE=1
    ;;
*)
esac


cd test

for arch in $ARCHS; do
    TEST_DIR="build-cmake-$arch"
    [ -z "$CLEAN" ] || rm -rf $TEST_DIR
    mkdir -p $TEST_DIR
    cd $TEST_DIR
    cmake \
        ${CMAKE_GENERATOR+-G} "$CMAKE_GENERATOR" \
        -DCMAKE_TOOLCHAIN_FILE=$PREFIX/share/cmake/$arch-w64-mingw32_toolchainfile.cmake \
        ..
    cmake --build . ${CORES:+-j${CORES}}
    cd ..
done

if [ -n "$NATIVE" ] && [ -f "$PREFIX/bin/libc++.dll" ]; then
    # Test if we can build with the native toolchain file, and execute the
    # output right away, by just having $PREFIX/bin in $PATH.
    #
    # (For msys2/mingw64 builds, the bin directory doesn't contain any
    # libc++.dll, so so skip this test in that configuration.)

    TEST_DIR="build-cmake-native"
    [ -z "$CLEAN" ] || rm -rf $TEST_DIR
    mkdir -p $TEST_DIR
    cd $TEST_DIR
    cmake \
        ${CMAKE_GENERATOR+-G} "$CMAKE_GENERATOR" \
        -DCMAKE_TOOLCHAIN_FILE=$PREFIX/share/cmake/llvm-mingw_toolchainfile.cmake \
        ..
    cmake --build . ${CORES:+-j${CORES}}

    # Add the toolchain bin directory to path, for dependency DLLs
    export PATH=$PREFIX/bin:$PATH
    for test in hello hello-cpp crt-test hello-res; do
        ./$test
    done
    cd ..
fi
echo All tests succeeded
