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
    CROSS_NAME=-$HOST
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
    INCLUDEDIR="$PREFIX/include"
else
    INCLUDEDIR="$PREFIX/generic-w64-mingw32/include"
fi
ANY_ARCH=$(echo $ARCHS | awk '{print $1}')

cd mingw-w64-tools/widl
[ -z "$CLEAN" ] || rm -rf build${CROSS_NAME}
mkdir -p build${CROSS_NAME}
cd build${CROSS_NAME}
../configure --prefix="$PREFIX" --target=$ANY_ARCH-w64-mingw32 --with-widl-includedir="$INCLUDEDIR" $CONFIGFLAGS
$MAKE -j$CORES
$MAKE install-strip
cd ..
cd "$PREFIX/bin"
# The build above produced $ANY_ARCH-w64-mingw32-widl, add symlinks to it
# with other prefixes.
for arch in $ARCHS; do
    if [ "$arch" != "$ANY_ARCH" ]; then
        ln -sf $ANY_ARCH-w64-mingw32-widl$EXEEXT $arch-w64-mingw32-widl$EXEEXT
    fi
done
if [ -n "$EXEEXT" ]; then
    # In a build of the tools for windows, we also want to provide an
    # unprefixed one. If crosscompiling, we know what the native arch is;
    # $HOST. If building natively, check the built clang to see what the
    # default arch is.
    if [ -z "$HOST" ] && [ -f clang$EXEEXT ]; then
        HOST=$(./clang -dumpmachine | sed 's/-.*//')-w64-mingw32
    fi
    if [ -n "$HOST" ]; then
        HOST_ARCH="${HOST%%-*}"
        # Only install an unprefixed symlink if $HOST is one of the architectures
        # we are installing wrappers for.
        case $ARCHS in
        *$HOST_ARCH*)
            ln -sf $HOST-widl$EXEEXT widl$EXEEXT
            ;;
        esac
    fi
fi
