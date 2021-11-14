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

: ${LIBFFI_VERSION:=v3.4.2}
: ${PYTHON_VERSION:=v3.9.7}
: ${PYTHON_VERSION_MINGW:=8736112bab36bc8f0612f33237f64473640ff3b8}

unset HOST

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
        echo $0 --host=triple dest
        exit 1
    fi

    mkdir -p "$PREFIX"
    PREFIX="$(cd "$PREFIX" && pwd)"
fi

MAKE=make
if [ -n "$(which gmake)" ]; then
    MAKE=gmake
fi

: ${CORES:=$(nproc 2>/dev/null)}
: ${CORES:=$(sysctl -n hw.ncpu 2>/dev/null)}
: ${CORES:=4}

if [ ! -d libffi ]; then
    git clone https://github.com/libffi/libffi.git
    CHECKOUT_LIBFFI=1
fi

if [ -n "$SYNC" ] || [ -n "$CHECKOUT_LIBFFI" ]; then
    cd libffi
    [ -z "$SYNC" ] || git fetch
    git checkout $LIBFFI_VERSION
    autoreconf -vfi
    cd ..
fi

if [ -z "$HOST" ]; then
    # Use a separate checkout for python for the native build;
    # mingw builds use a separate fork, maintained by msys2
    # which doesn't build on regular Unix
    if [ ! -d cpython-native ]; then
        git clone https://github.com/python/cpython.git cpython-native
        CHECKOUT_PYTHON_NATIVE=1
    fi

    if [ -n "$SYNC" ] || [ -n "$CHECKOUT_PYTHON_NATIVE" ]; then
        cd cpython-native
        [ -z "$SYNC" ] || git fetch
        git checkout $PYTHON_VERSION
        cd ..
    fi

    [ -z "$CHECKOUT_ONLY" ] || exit 0

    cd libffi
    [ -z "$CLEAN" ] || rm -rf $BUILDDIR
    mkdir -p $BUILDDIR
    cd $BUILDDIR
    ../configure --prefix="$PREFIX" --disable-symvers --disable-docs
    $MAKE -j$CORES
    $MAKE install
    cd ../..

    cd cpython-native
    [ -z "$CLEAN" ] || rm -rf $BUILDDIR
    mkdir -p $BUILDDIR
    cd $BUILDDIR
    ../configure --prefix="$PREFIX" \
        CFLAGS="-I$PREFIX/include" CXXFLAGS="-I$PREFIX/include" LDFLAGS="-L$PREFIX/lib -Wl,-s" \
        --without-ensurepip
    $MAKE -j$CORES
    $MAKE install
    exit 0
fi

# Fetching
if [ ! -d cpython-mingw ]; then
    git clone https://github.com/msys2-contrib/cpython-mingw.git
    CHECKOUT_PYTHON=1
fi

if [ -n "$SYNC" ] || [ -n "$CHECKOUT_PYTHON" ]; then
    cd cpython-mingw
    [ -z "$SYNC" ] || git fetch
    git checkout $PYTHON_VERSION_MINGW
    autoreconf -vfi
    cd ..
fi

[ -z "$CHECKOUT_ONLY" ] || exit 0

cd libffi
[ -z "$CLEAN" ] || rm -rf $BUILDDIR
mkdir -p $BUILDDIR
cd $BUILDDIR
../configure --prefix="$PREFIX" --host=$HOST --disable-symvers --disable-docs
$MAKE -j$CORES
$MAKE install
cd ../..

cd cpython-mingw
[ -z "$CLEAN" ] || rm -rf $BUILDDIR
mkdir -p $BUILDDIR
cd $BUILDDIR
BUILD=$(../config.guess) # Python configure requires build triplet for cross compilation

export CC=$HOST-clang
export CXX=$HOST-clang++

../configure --prefix="$PREFIX" --build=$BUILD --host=$HOST \
    CFLAGS="-I$PREFIX/include" CXXFLAGS="-I$PREFIX/include" LDFLAGS="-L$PREFIX/lib -Wl,-s" \
    --enable-shared             \
    --with-system-ffi           \
    --without-ensurepip         \
    --without-c-locale-coercion

$MAKE -j$CORES
$MAKE install
rm -rf $PREFIX/lib/python*/test
find $PREFIX/lib/python* -name __pycache__ | xargs rm -rf
cd ../..
