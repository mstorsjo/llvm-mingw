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

: ${DEFAULT_WIN32_WINNT:=0x601}
: ${DEFAULT_MSVCRT:=ucrt}
: ${MINGW_W64_VERSION:=d4a0c84d908243a45255a06dc293d3d7c06db98c}

while [ $# -gt 0 ]; do
    case "$1" in
    --skip-include-triplet-prefix)
        SKIP_INCLUDE_TRIPLET_PREFIX=1
        ;;
    --with-default-win32-winnt=*)
        DEFAULT_WIN32_WINNT="${1#*=}"
        ;;
    --with-default-msvcrt=*)
        DEFAULT_MSVCRT="${1#*=}"
        ;;
    *)
        PREFIX="$1"
        ;;
    esac
    shift
done
if [ -z "$CHECKOUT_ONLY" ]; then
    if [ -z "$PREFIX" ]; then
        echo $0 [--skip-include-triplet-prefix] [--with-default-win32-winnt=0x601] [--with-default-msvcrt=ucrt] dest
        exit 1
    fi

    mkdir -p "$PREFIX"
    PREFIX="$(cd "$PREFIX" && pwd)"
fi

if [ ! -d mingw-w64 ]; then
    git clone https://github.com/mingw-w64/mingw-w64
    CHECKOUT=1
fi

cd mingw-w64

if [ -n "$SYNC" ] || [ -n "$CHECKOUT" ]; then
    [ -z "$SYNC" ] || git fetch
    git checkout $MINGW_W64_VERSION
fi

[ -z "$CHECKOUT_ONLY" ] || exit 0

MAKE=make
if command -v gmake >/dev/null; then
    MAKE=gmake
fi

export PATH="$PREFIX/bin:$PATH"

unset CC

: ${CORES:=$(nproc 2>/dev/null)}
: ${CORES:=$(sysctl -n hw.ncpu 2>/dev/null)}
: ${CORES:=4}
: ${ARCHS:=${TOOLCHAIN_ARCHS-i686 x86_64 armv7 aarch64}}

if [ -z "$SKIP_INCLUDE_TRIPLET_PREFIX" ]; then
    HEADER_ROOT="$PREFIX/generic-w64-mingw32"
else
    HEADER_ROOT="$PREFIX"
fi

cd mingw-w64-headers
[ -z "$CLEAN" ] || rm -rf build
mkdir -p build
cd build
../configure --prefix="$HEADER_ROOT" \
    --enable-idl --with-default-win32-winnt=$DEFAULT_WIN32_WINNT --with-default-msvcrt=$DEFAULT_MSVCRT INSTALL="install -C"
$MAKE install
cd ../..
if [ -z "$SKIP_INCLUDE_TRIPLET_PREFIX" ]; then
    for arch in $ARCHS; do
        mkdir -p "$PREFIX/$arch-w64-mingw32"
        if [ ! -e "$PREFIX/$arch-w64-mingw32/include" ]; then
            ln -sfn ../generic-w64-mingw32/include "$PREFIX/$arch-w64-mingw32/include"
        fi
    done
fi

cd mingw-w64-crt
for arch in $ARCHS; do
    [ -z "$CLEAN" ] || rm -rf build-$arch
    mkdir -p build-$arch
    cd build-$arch
    case $arch in
    armv7)
        FLAGS="--disable-lib32 --disable-lib64 --enable-libarm32"
        ;;
    aarch64)
        FLAGS="--disable-lib32 --disable-lib64 --enable-libarm64"
        ;;
    i686)
        FLAGS="--enable-lib32 --disable-lib64"
        ;;
    x86_64)
        FLAGS="--disable-lib32 --enable-lib64"
        ;;
    esac
    FLAGS="$FLAGS --with-default-msvcrt=$DEFAULT_MSVCRT"
    ../configure --host=$arch-w64-mingw32 --prefix="$PREFIX/$arch-w64-mingw32" $FLAGS
    $MAKE -j$CORES
    $MAKE install
    cd ..
done
cd ..

for arch in $ARCHS; do
    mkdir -p "$PREFIX/$arch-w64-mingw32/share/mingw32"
    for file in COPYING COPYING.MinGW-w64/COPYING.MinGW-w64.txt COPYING.MinGW-w64-runtime/COPYING.MinGW-w64-runtime.txt; do
        install -m644 "$file" "$PREFIX/$arch-w64-mingw32/share/mingw32"
    done
done
