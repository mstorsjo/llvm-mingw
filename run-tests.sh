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
: ${ARCHS:=${TOOLCHAIN_ARCHS-i686 x86_64 armv7 aarch64}}

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
    eval "NATIVE=\"\${NATIVE_${arch}}\""

    unset QEMU
    unset INTERPRETER
    if [ -n "$NATIVE" ]; then
        INTERPRETER=$PREFIX/$arch-linux-musl/lib/ld-musl-$arch.so.1
    else
        qemu_arch=$arch
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
    $MAKE -f ../Makefile ARCH=$arch NATIVE=$NATIVE SYSROOT=$PREFIX/$arch-linux-musl clean
    $MAKE -f ../Makefile ARCH=$arch NATIVE=$NATIVE SYSROOT=$PREFIX/$arch-linux-musl QEMU=$QEMU INTERPRETER=$INTERPRETER $MAKEOPTS -j$CORES $TARGET
    cd ..
done
echo All tests succeeded
