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

LLVM_ARGS=""
MINGW_ARGS=""

while [ $# -gt 0 ]; do
    case "$1" in
    --enable-asserts)
        LLVM_ARGS="$LLVM_ARGS $1"
        ;;
    --full-llvm)
        LLVM_ARGS="$LLVM_ARGS $1"
        FULL_LLVM=1
        ;;
    --disable-dylib)
        LLVM_ARGS="$LLVM_ARGS $1"
        ;;
    --disable-lldb)
        LLVM_ARGS="$LLVM_ARGS $1"
        NO_LLDB=1
        ;;
    --disable-clang-tools-extra)
        LLVM_ARGS="$LLVM_ARGS $1"
        ;;
    --with-default-msvcrt=*)
        MINGW_ARGS="$MINGW_ARGS $1"
        ;;
    --with-default-win32-winnt=*)
        MINGW_ARGS="$MINGW_ARGS $1"
        ;;
    *)
        if [ -n "$PREFIX" ]; then
            echo Unrecognized parameter $1
            exit 1
        fi
        PREFIX="$1"
        ;;
    esac
    shift
done
if [ -z "$PREFIX" ]; then
    echo $0 [--enable-asserts] [--disable-dylib] [--full-llvm] [--with-python] [--symlink-projects] [--disable-lldb] [--disable-clang-tools-extra] [--host=triple] [--with-default-win32-winnt=0x601] [--with-default-msvcrt=ucrt] dest
    exit 1
fi

for dep in git curl cmake; do
    if ! hash $dep 2>/dev/null; then
        echo "$dep not installed. Please install it and retry" 1>&2
        exit 1
    fi
done

./build-llvm.sh $PREFIX $LLVM_ARGS
if [ -z "$NO_LLDB" ]; then
    ./build-lldb-mi.sh $PREFIX
fi
if [ -z "$FULL_LLVM" ]; then
    ./strip-llvm.sh $PREFIX
fi
./install-wrappers.sh $PREFIX
./build-mingw-w64.sh $PREFIX $MINGW_ARGS
./build-mingw-w64-tools.sh $PREFIX
./build-compiler-rt.sh $PREFIX
./build-libcxx.sh $PREFIX
./build-mingw-w64-libraries.sh $PREFIX
./build-compiler-rt.sh $PREFIX --build-sanitizers
./build-libssp.sh $PREFIX
./build-openmp.sh $PREFIX
