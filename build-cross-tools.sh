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

while [ $# -gt 0 ]; do
    case "$1" in
    --with-python)
        PYTHON=1
        ;;
    --disable-lldb)
        LLVM_ARGS="$LLVM_ARGS $1"
        NO_LLDB=1
        ;;
    --disable-lldb-mi)
        NO_LLDB_MI=1
        ;;
    --disable-clang-tools-extra)
        LLVM_ARGS="$LLVM_ARGS $1"
        ;;
    --disable-mingw-w64-tools)
        NO_MINGW_W64_TOOLS=1
        ;;
    --full-llvm)
        LLVM_ARGS="$LLVM_ARGS $1"
        FULL_LLVM=1
        ;;
    --disable-make)
        NO_MAKE=1
        ;;
    *)
        if [ -z "$NATIVE" ]; then
            NATIVE="$1"
        elif [ -z "$PREFIX" ]; then
            PREFIX="$1"
        elif [ -z "$CROSS_ARCH" ]; then
            CROSS_ARCH="$1"
        else
            echo Unrecognized parameter $1
            exit 1
        fi
        ;;
    esac
    shift
done
if [ -z "$CROSS_ARCH" ]; then
    echo $0 native prefix arch [--with-python] [--disable-lldb] [--disable-lldb-mi] [--disable-clang-tool-extra] [--disable-mingw-w64-tools] [--disable-make]
    exit 1
fi

for dep in git curl cmake; do
    if ! command -v $dep >/dev/null; then
        echo "$dep not installed. Please install it and retry" 1>&2
        exit 1
    fi
done

export PATH="$NATIVE/bin:$PATH"
HOST=$CROSS_ARCH-w64-mingw32

if [ -n "$PYTHON" ]; then
    PYTHON_NATIVE_PREFIX="$(cd "$(dirname "$0")" && pwd)/python-native"
    [ -d "$PYTHON_NATIVE_PREFIX" ] || rm -rf "$PYTHON_NATIVE_PREFIX"
    ./build-python.sh $PYTHON_NATIVE_PREFIX
    export PATH="$PYTHON_NATIVE_PREFIX/bin:$PATH"
    ./build-python.sh $PREFIX/python --host=$HOST
    mkdir -p $PREFIX/bin
    cp $PREFIX/python/bin/*.dll $PREFIX/bin
    LLVM_ARGS="$LLVM_ARGS --with-python"
fi

./build-llvm.sh $PREFIX --host=$HOST $LLVM_ARGS
if [ -z "$NO_LLDB" ] && [ -z "$NO_LLDB_MI" ]; then
    ./build-lldb-mi.sh $PREFIX --host=$HOST
fi
if [ -z "$FULL_LLVM" ]; then
    ./strip-llvm.sh $PREFIX --host=$HOST
fi
if [ -z "$NO_MINGW_W64_TOOLS" ]; then
    ./build-mingw-w64-tools.sh $PREFIX --skip-include-triplet-prefix --host=$HOST
fi
./install-wrappers.sh $PREFIX --host=$HOST
./prepare-cross-toolchain.sh $NATIVE $PREFIX $CROSS_ARCH
if [ -z "$NO_MAKE" ]; then
    ./build-make.sh $PREFIX --host=$HOST
fi
