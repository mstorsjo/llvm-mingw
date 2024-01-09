#!/bin/sh
#
# Copyright (c) 2023 Martin Storsjo
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

: ${LINUX_VERSION:=v6.6}

while [ $# -gt 0 ]; do
    case "$1" in
    --full)
        FULL=1
        ;;
    *)
        PREFIX="$1"
        ;;
    esac
    shift
done
if [ -z "$CHECKOUT_ONLY" ]; then
    if [ -z "$PREFIX" ]; then
        echo $0 [--full] dest
        exit 1
    fi

    mkdir -p "$PREFIX"
    PREFIX="$(cd "$PREFIX" && pwd)"
fi

if [ ! -d linux ]; then
    mkdir linux
    cd linux
    git init
    git remote add origin https://github.com/torvalds/linux.git
    cd ..
    CHECKOUT=1
fi

cd linux

if [ -n "$SYNC" ] || [ -n "$CHECKOUT" ]; then
    # Check if the intended commit or tag exists in the local repo. If it
    # exists, just check it out instead of trying to fetch it.
    # (Redoing a shallow fetch will refetch the data even if the commit
    # already exists locally, unless fetching a tag with the "tag"
    # argument.)
    if git cat-file -e "$LINUX_VERSION" 2> /dev/null; then
        # Exists; just check it out
        git checkout "$LINUX_VERSION"
    else
        case "$LINUX_VERSION" in
        v*.*)
            # If $LINUX_VERSION looks like a tag, fetch it with the
            # "tag" keyword. This makes sure that the local repo
            # gets the tag too, not only the commit itself. This allows
            # later fetches to realize that the tag already exists locally.
            git fetch --depth 1 origin tag "$LINUX_VERSION"
            git checkout "$LINUX_VERSION"
            ;;
        *)
            git fetch --depth 1 origin "$LINUX_VERSION"
            git checkout FETCH_HEAD
            ;;
        esac
    fi
fi

[ -z "$CHECKOUT_ONLY" ] || exit 0

MAKE=make
if command -v gmake >/dev/null; then
    MAKE=gmake
fi

export PATH="$PREFIX/bin:$PATH"

: ${CORES:=$(nproc 2>/dev/null)}
: ${CORES:=$(sysctl -n hw.ncpu 2>/dev/null)}
: ${CORES:=4}
: ${ARCHS:=${TOOLCHAIN_ARCHS-i386 x86_64 arm aarch64 powerpc64le riscv64}}

# libcxx requires linux/futex.h
# compiler-rt for riscv requires linux/unistd.h
# lldb requires linux/perf_event.h, linux/version.h, asm/ptrace.h, asm/hwcap.h (asm/hwcap.h doesn't exist in all archiectures)
: ${HEADERS:=linux/futex.h linux/unistd.h linux/perf_event.h linux/version.h asm/ptrace.h asm/hwcap.h}

mkdir -p $PREFIX/generic-linux-musl/usr/include

for arch in $ARCHS; do
    triple=$arch-linux-musl
    multiarch_triple=$arch-linux-gnu
    case $arch in
    arm*)
        triple=$arch-linux-musleabihf
        multiarch_triple=$arch-linux-gnueabihf
        ;;
    i*86)
        multiarch_triple=i386-linux-gnu
        ;;
    esac

    [ -z "$CLEAN" ] || rm -rf build-$arch
    mkdir -p build-$arch
    cd build-$arch
    case $arch in
    i*86)
        linuxarch=i386
        ;;
    arm*)
        linuxarch=arm
        ;;
    aarch64)
        linuxarch=arm64
        ;;
    powerpc*)
        linuxarch=powerpc
        ;;
    riscv*)
        linuxarch=riscv
        ;;
    *)
        linuxarch=$arch
        ;;
    esac
    includes="$PREFIX/generic-linux-musl/usr/include"

    mkdir -p $includes/$multiarch_triple/asm
    mv $includes/$multiarch_triple/asm $includes

    dest=$PREFIX/generic-linux-musl/usr
    if [ -z "$FULL" ]; then
        dest=$(pwd)/temp
    fi
    $MAKE -f ../Makefile headers_install ARCH=$linuxarch INSTALL_HDR_PATH=$dest -j$CORES
    if [ -z "$FULL" ]; then
        cur_arch_headers=""
        for h in $HEADERS; do
            if [ -e $dest/include/$h ]; then
                cur_arch_headers="$cur_arch_headers -include $h"
            fi
        done
        for i in $($triple-clang -I$dest/include $cur_arch_headers - -E -MM < /dev/null | sed 's/^.*://;s/\\$//' | grep $dest/include | sed s,$dest/include/,,); do
            if [ "$(dirname $i)" != "." ]; then
                mkdir -p "$PREFIX/generic-linux-musl/usr/include/$(dirname $i)"
            fi
            echo Copying $i
            cp "$dest/include/$i" "$PREFIX/generic-linux-musl/usr/include/$i"
        done
    fi

    mv $includes/asm $includes/$multiarch_triple
    cd ..
done
