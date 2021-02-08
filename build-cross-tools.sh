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

if [ $# -lt 3 ]; then
    echo $0 native prefix arch [--with-python]
    exit 1
fi
NATIVE="$1"
PREFIX="$2"
CROSS_ARCH="$3"

export PATH="$NATIVE/bin:$PATH"
HOST=$CROSS_ARCH-w64-mingw32

if [ "$4" = "--with-python" ]; then
    PYTHON_NATIVE_PREFIX="$(cd "$(dirname "$0")" && pwd)/python-native"
    [ -d "$PYTHON_NATIVE_PREFIX" ] || rm -rf "$PYTHON_NATIVE_PREFIX"
    ./build-python.sh $PYTHON_NATIVE_PREFIX
    export PATH="$PYTHON_NATIVE_PREFIX/bin:$PATH"
    ./build-python.sh $PREFIX/python --host=$HOST
    mkdir -p $PREFIX/bin
    cp $PREFIX/python/bin/*.dll $PREFIX/bin
    LLVM_WITH_PYTHON="--with-python"
fi

./build-llvm.sh $PREFIX --host=$HOST $LLVM_WITH_PYTHON
./build-lldb-mi.sh $PREFIX --host=$HOST
./strip-llvm.sh $PREFIX --host=$HOST
./build-mingw-w64-tools.sh $PREFIX --skip-include-triplet-prefix --host=$HOST
./install-wrappers.sh $PREFIX --host=$HOST
./prepare-cross-toolchain.sh $NATIVE $PREFIX $CROSS_ARCH
./build-make.sh $PREFIX --host=$HOST
