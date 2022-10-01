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

CFGUARD_CFLAGS="-mguard=cf"

while [ $# -gt 0 ]; do
    case "$1" in
    --enable-cfguard)
        CFGUARD_CFLAGS="-mguard=cf"
        ;;
    --disable-cfguard)
        CFGUARD_CFLAGS=
        ;;
    *)
        PREFIX="$1"
        ;;
    esac
    shift
done
if [ -z "$PREFIX" ]; then
    echo "$0 [--enable-cfguard|--disable-cfguard] dest"
    exit 1
fi

MAKE=make
if command -v gmake >/dev/null; then
    MAKE=gmake
fi

mkdir -p "$PREFIX"
PREFIX="$(cd "$PREFIX" && pwd)"
export PATH="$PREFIX/bin:$PATH"

: ${CORES:=$(nproc 2>/dev/null)}
: ${CORES:=$(sysctl -n hw.ncpu 2>/dev/null)}
: ${CORES:=4}
: ${ARCHS:=${TOOLCHAIN_ARCHS-i686 x86_64 armv7 aarch64}}

download() {
    if command -v wget >/dev/null; then
        if [ -n "$2" ]; then
            wget -O "$2" "$1"
        else
            wget "$1"
        fi
    else
        if [ -n "$2" ]; then
            curl -L -o "$2" "$1"
        else
            curl -LO "$1"
        fi
    fi
}

if [ ! -d libssp ]; then
    download 'https://gitlab.com/watched/gcc-mirror/gcc/-/archive/releases/gcc-7.3.0/gcc-releases-gcc-7.3.0.tar.bz2?path=libssp' libssp.tar.bz2
    tar xf libssp.tar.bz2 --strip-components=1
    rm -f libssp.tar.bz2
fi

cp libssp-Makefile libssp/Makefile

cd libssp

# gcc/libssp's configure script runs checks for flags that clang doesn't
# implement. We actually just need to set a few HAVE defines and compile
# the .c sources.
cp config.h.in config.h
for i in HAVE_FCNTL_H HAVE_INTTYPES_H HAVE_LIMITS_H HAVE_MALLOC_H \
    HAVE_MEMMOVE HAVE_MEMORY_H HAVE_MEMPCPY HAVE_STDINT_H HAVE_STDIO_H \
    HAVE_STDLIB_H HAVE_STRINGS_H HAVE_STRING_H HAVE_STRNCAT HAVE_STRNCPY \
    HAVE_SYS_STAT_H HAVE_SYS_TYPES_H HAVE_UNISTD_H HAVE_USABLE_VSNPRINTF \
    HAVE_HIDDEN_VISIBILITY; do
    cat config.h | sed 's/^#undef '$i'$/#define '$i' 1/' > tmp
    mv tmp config.h
done
cat ssp/ssp.h.in | sed 's/@ssp_have_usable_vsnprintf@/define/' > ssp/ssp.h

for arch in $ARCHS; do
    [ -z "$CLEAN" ] || rm -rf build-$arch
    mkdir -p build-$arch
    cd build-$arch
    $MAKE -f ../Makefile -j$CORES CROSS=$arch-w64-mingw32- CFGUARD_CFLAGS="$CFGUARD_CFLAGS"
    mkdir -p "$PREFIX/$arch-w64-mingw32/bin"
    cp libssp.a "$PREFIX/$arch-w64-mingw32/lib"
    cp libssp_nonshared.a "$PREFIX/$arch-w64-mingw32/lib"
    cp libssp.dll.a "$PREFIX/$arch-w64-mingw32/lib"
    cp libssp-0.dll "$PREFIX/$arch-w64-mingw32/bin"
    cd ..
done
