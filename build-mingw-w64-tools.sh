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

unset HOST

while [ $# -gt 0 ]; do
    case "$1" in
    --skip-include-triplet-prefix)
        SKIP_INCLUDE_TRIPLET_PREFIX=1
        ;;
    --host=*)
        HOST="${1#*=}"
        ;;
    *)
        PREFIX="$1"
        ;;
    esac
    shift
done
if [ -z "$CHECKOUT_ONLY" ]; then
    if [ -z "$PREFIX" ]; then
        echo $0 [--skip-include-triplet-prefix] [--host=<triple>] dest
        exit 1
    fi

    mkdir -p "$PREFIX"
    PREFIX="$(cd "$PREFIX" && pwd)"
fi

if [ ! -d mingw-w64 ] || [ -n "$SYNC" ]; then
    CHECKOUT_ONLY=1 ./build-mingw-w64.sh
fi

cd mingw-w64

MAKE=make
if [ "$(which gmake)" != "" ]; then
    MAKE=gmake
fi

: ${CORES:=$(nproc 2>/dev/null)}
: ${CORES:=$(sysctl -n hw.ncpu 2>/dev/null)}
: ${CORES:=4}
: ${ARCHS:=${TOOLCHAIN_ARCHS-i686 x86_64 armv7 aarch64}}

if [ -n "$HOST" ]; then
    CONFIGFLAGS="$CONFIGFLAGS --host=$HOST"
    CROSS_NAME=$HOST-
    EXEEXT=.exe
else
    case $(uname) in
    MINGW*)
        EXEEXT=.exe
        ;;
    *)
        ;;
    esac
fi
if [ -n "$SKIP_INCLUDE_TRIPLET_PREFIX" ]; then
    CONFIGFLAGS="$CONFIGFLAGS --with-widl-includedir=$PREFIX/include"
    # If using the same includedir for all archs, it's enough to
    # build one single binary.
    ALL_ARCHS="$ARCHS"
    ARCHS=x86_64
fi

cd mingw-w64-tools/widl
for arch in $ARCHS; do
    [ -z "$CLEAN" ] || rm -rf build-$CROSS_NAME$arch
    mkdir -p build-$CROSS_NAME$arch
    cd build-$CROSS_NAME$arch
    ../configure --prefix="$PREFIX" --target=$arch-w64-mingw32 $CONFIGFLAGS
    $MAKE -j$CORES
    $MAKE install-strip
    cd ..
done
cd "$PREFIX/bin"
if [ -n "$SKIP_INCLUDE_TRIPLET_PREFIX" ]; then
    for arch in $ALL_ARCHS; do
        if [ "$arch" != "$ARCHS" ]; then
            ln -sf $ARCHS-w64-mingw32-widl$EXEEXT $arch-w64-mingw32-widl$EXEEXT
        fi
    done
fi
if [ -n "$EXEEXT" ]; then
    if [ -z "$HOST" ] && [ -f clang$EXEEXT ]; then
        HOST=$(./clang -dumpmachine | sed 's/-.*//')-w64-mingw32
    fi
    if [ -n "$HOST" ]; then
        ln -sf $HOST-widl$EXEEXT widl$EXEEXT
    fi
fi
