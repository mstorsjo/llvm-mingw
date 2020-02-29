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
: ${MINGW_W64_VERSION:=62259d490b684fcc3ba4ef0b36427d89cc2817f7}
unset HOST

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
    --host=*)
        HOST="${1#*=}"
        ;;
    *)
        PREFIX="$1"
        ;;
    esac
    shift
done
if [ -z "$PREFIX" ]; then
    echo $0 [--skip-include-triplet-prefix] [--with-default-win32-winnt=0x601] [--with-default-msvcrt=ucrt] [--host=<triple>] dest
    exit 1
fi

MAKE=make
if [ "$(which gmake)" != "" ]; then
    MAKE=gmake
fi

mkdir -p "$PREFIX"
PREFIX="$(cd "$PREFIX" && pwd)"

ORIGPATH="$PATH"
if [ -z "$HOST" ]; then
    # The newly built toolchain isn't crosscompiled; add it to the path.
    export PATH="$PREFIX/bin:$PATH"
else
    # Crosscompiling the toolchain itself; the cross compiler is
    # expected to already be in $PATH.
    true
fi

: ${CORES:=$(nproc 2>/dev/null)}
: ${CORES:=$(sysctl -n hw.ncpu 2>/dev/null)}
: ${CORES:=4}
: ${ARCHS:=${TOOLCHAIN_ARCHS-i686 x86_64 armv7 aarch64}}

if [ ! -d mingw-w64 ]; then
    git clone git://git.code.sf.net/p/mingw-w64/mingw-w64
    CHECKOUT=1
fi

cd mingw-w64

if [ -n "$SYNC" ] || [ -n "$CHECKOUT" ]; then
    [ -z "$SYNC" ] || git fetch
    git checkout $MINGW_W64_VERSION
fi

# If crosscompiling the toolchain itself, we already have a mingw-w64
# runtime and don't need to rebuild it.
if [ -z "$HOST" ]; then
    if [ -z "$SKIP_INCLUDE_TRIPLET_PREFIX" ]; then
        HEADER_ROOT="$PREFIX/generic-w64-mingw32"
    else
        HEADER_ROOT="$PREFIX"
    fi

    cd mingw-w64-headers
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
fi

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

# If building on windows, we've installed prefixless wrappers - these break
# building widl, as the toolchain isn't functional yet. Restore the original
# path.
export PATH="$ORIGPATH"
cd mingw-w64-tools/widl
for arch in $ARCHS; do
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
