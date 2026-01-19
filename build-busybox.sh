#!/bin/sh
#
# Copyright (c) 2025 Martin Storsjo
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

: ${BUSYBOX_VERSION:=1f493261d16be3d984fe8a689f5113dafb6eaaa7}

BUILDDIR=build

while [ $# -gt 0 ]; do
    case "$1" in
    --host=*)
        HOST="${1#*=}"
        BUILDDIR=$BUILDDIR-$HOST
        ;;
    *)
        PREFIX="$1"
        ;;
    esac
    shift
done

if [ -z "$CHECKOUT_ONLY" ]; then
    if [ -z "$PREFIX" ]; then
        echo $0 [--host=triple] dest
        exit 1
    fi

    mkdir -p "$PREFIX"
    PREFIX="$(cd "$PREFIX" && pwd)"
fi

MAKE=make
if command -v gmake >/dev/null; then
    MAKE=gmake
fi

: ${CORES:=$(nproc 2>/dev/null)}
: ${CORES:=$(sysctl -n hw.ncpu 2>/dev/null)}
: ${CORES:=4}

if [ ! -d busybox-w32 ]; then
    git clone https://github.com/rmyorston/busybox-w32
    CHECKOUT=1
fi

SRC=$(pwd)

cd busybox-w32

if [ -n "$SYNC" ] || [ -n "$CHECKOUT" ]; then
    [ -z "$SYNC" ] || git fetch
    git checkout $BUSYBOX_VERSION
fi

[ -z "$CHECKOUT_ONLY" ] || exit 0

[ -z "$CLEAN" ] || rm -rf $BUILDDIR
mkdir -p $BUILDDIR
make mingw64a_defconfig O=$BUILDDIR -j$CORES
cd $BUILDDIR
sed -ri 's/^(CONFIG_AR)=y/\1=n/' .config
sed -ri 's/^(CONFIG_FEATURE_FAIL_IF_UTF8_MANIFEST_UNSUPPORTED)=y/\1=n/' .config
sed -ri 's/^(CONFIG_MAKE)=y/\1=n/' .config
$MAKE -j$CORES CROSS_COMPILE=${HOST+$HOST-}
cp ../LICENSE $PREFIX/LICENSE.txt
mkdir -p $PREFIX/bin
cp busybox.exe $PREFIX/bin

WRAPPER_FLAGS="$WRAPPER_FLAGS -municode -D__USE_MINGW_ANSI_STDIO=0"

${HOST+$HOST-}gcc $SRC/wrappers/busybox-wrapper.c -o $PREFIX/bin/busybox-wrapper.exe -O2 -Wl,-s $WRAPPER_FLAGS

cc $SRC/wrappers/busybox-list-applets.c -I. -o busybox-list-applets
./busybox-list-applets > applets.txt
for i in $(cat applets.txt); do
    case $i in
    busybox|[*)
        continue
        ;;
    esac
    ln -sf busybox-wrapper.exe $PREFIX/bin/$i.exe
done
