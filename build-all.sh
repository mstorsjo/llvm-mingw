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
CFGUARD_ARGS="--disable-cfguard"
MINGW_TOOLS_ARGS=""
MINGW_LIBRARIES_ARGS=""

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
    --disable-lldb-mi)
        NO_LLDB_MI=1
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
    --enable-cfguard)
        CFGUARD_ARGS="--enable-cfguard"
        ;;
    --disable-cfguard)
        CFGUARD_ARGS="--disable-cfguard"
        ;;
    --no-runtimes)
        NO_RUNTIMES=1
        ;;
    --skip-include-triplet-prefix)
        MINGW_ARGS="$MINGW_ARGS $1"
        MINGW_TOOLS_ARGS="$MINGW_TOOLS_ARGS $1"
        MINGW_LIBRARIES_ARGS="$MINGW_LIBRARIES_ARGS $1"
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
    echo "$0 [--enable-asserts] [--disable-dylib] [--full-llvm] [--with-python] [--symlink-projects] [--disable-lldb] [--disable-lldb-mi] [--disable-clang-tools-extra] [--host=triple] [--with-default-win32-winnt=0x601] [--with-default-msvcrt=ucrt] [--enable-cfguard|--disable-cfguard] [--no-runtimes] [--skip-include-triplet-prefix] dest"
    exit 1
fi

for dep in git curl cmake; do
    if ! command -v $dep >/dev/null; then
        echo "$dep not installed. Please install it and retry" 1>&2
        exit 1
    fi
done

./build-llvm.sh $PREFIX $LLVM_ARGS
if [ -z "$NO_LLDB" ] && [ -z "$NO_LLDB_MI" ]; then
    ./build-lldb-mi.sh $PREFIX
fi
if [ -z "$FULL_LLVM" ]; then
    ./strip-llvm.sh $PREFIX
fi
./install-wrappers.sh $PREFIX
./build-mingw-w64-tools.sh $PREFIX $MINGW_TOOLS_ARGS
if [ -n "$NO_RUNTIMES" ]; then
    exit 0
fi
./build-mingw-w64.sh $PREFIX $MINGW_ARGS $CFGUARD_ARGS
./build-compiler-rt.sh $PREFIX $CFGUARD_ARGS
./build-libcxx.sh $PREFIX $CFGUARD_ARGS
./build-mingw-w64-libraries.sh $PREFIX $MINGW_LIBRARIES_ARGS $CFGUARD_ARGS
./build-compiler-rt.sh $PREFIX --build-sanitizers # CFGUARD_ARGS intentionally omitted
./build-libssp.sh $PREFIX $CFGUARD_ARGS
./build-openmp.sh $PREFIX $CFGUARD_ARGS
