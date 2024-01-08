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

set -ex

if [ $# -lt 1 ]; then
    echo $0 dest
    exit 1
fi
PREFIX="$1"
PREFIX="$(cd "$PREFIX" && pwd)"
export PATH=$PREFIX/bin:$PATH

: ${CORES:=$(nproc 2>/dev/null)}
: ${CORES:=$(sysctl -n hw.ncpu 2>/dev/null)}
: ${CORES:=4}
: ${ARCHS:=${TOOLCHAIN_ARCHS-i386 x86_64 arm aarch64 powerpc64le riscv64}}

MAKE=make
if command -v gmake >/dev/null; then
    MAKE=gmake
fi

case $(uname -s) in
Darwin)
    ;;
*)
    # Assume everything except macOS has got GNU make >= 4.0
    MAKEOPTS="-O"
esac

cd test

ANY_ARCH=$(echo $ARCHS | awk '{print $1}')

if [ "$(uname)" = "Linux" ]; then
    case $(uname -m) in
    i*86)
        NATIVE_i386=1
        ;;
    x86_64)
        NATIVE_i386=1
        NATIVE_x86_64=1
        ;;
    armv7*)
        NATIVE_arm=1
        ;;
    aarch64)
        NATIVE_arm=1
        NATIVE_aarch64=1
        ;;
    esac
fi


for arch in $ARCHS; do
    triple=$arch-linux-musl
    normalized_arch=$arch
    musl_arch=$arch
    qemu_arch=$arch
    multiarch_triple=$arch-linux-gnu
    case $arch in
    i*86)
        normalized_arch=i386
        musl_arch=i386
        qemu_arch=i386
        multiarch_triple=i386-linux-gnu
        ;;
    arm*)
        triple=$arch-linux-musleabihf
        normalized_arch=arm
        musl_arch=armhf
        qemu_arch=armhf
        multiarch_triple=$arch-linux-gnueabihf
        ;;
    powerpc64le)
        qemu_arch=ppc64le
        ;;
    esac
    eval "NATIVE=\"\${NATIVE_${normalized_arch}}\""

    unset QEMU
    unset INTERPRETER
    if [ -n "$NATIVE" ]; then
        INTERPRETER=$PREFIX/generic-linux-musl/lib/ld-musl-$musl_arch.so.1
    else
        if command -v qemu-$qemu_arch-static >/dev/null; then
            QEMU=qemu-$qemu_arch-static
        elif command -v qemu-$qemu_arch >/dev/null; then
            QEMU=qemu-$qemu_arch
        fi
    fi

    TARGET=all
    if [ -n "$NATIVE" ] || [ -n "$QEMU" ]; then
        TARGET=test
    fi

    TEST_DIR="$arch"
    [ -z "$CLEAN" ] || rm -rf $TEST_DIR
    mkdir -p $TEST_DIR
    cd $TEST_DIR
    $MAKE -f ../Makefile TRIPLE=$triple NATIVE=$NATIVE SYSROOT=$PREFIX/generic-linux-musl clean
    $MAKE -f ../Makefile TRIPLE=$triple NATIVE=$NATIVE SYSROOT=$PREFIX/generic-linux-musl LIBDIR=$PREFIX/generic-linux-musl/usr/lib/$multiarch_triple QEMU=$QEMU INTERPRETER=$INTERPRETER $MAKEOPTS -j$CORES $TARGET
    cd ..
done
echo All tests succeeded
