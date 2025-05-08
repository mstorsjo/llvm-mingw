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

HOST_CLANG=
LLVM_ARGS=""
MINGW_ARGS=""
CFGUARD_ARGS="--enable-cfguard"
HOST_ARGS=""

while [ $# -gt 0 ]; do
    case "$1" in
    --enable-asserts|--disable-dylib|--with-clang|--thinlto)
        LLVM_ARGS="$LLVM_ARGS $1"
        ;;
    --host-clang|--host-clang=*)
        HOST_CLANG=${1#--host-clang}
        HOST_CLANG=${HOST_CLANG#=}
        HOST_CLANG=${HOST_CLANG:-clang}
        ;;
    --full-llvm)
        LLVM_ARGS="$LLVM_ARGS $1"
        FULL_LLVM=1
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
    --host=*)
        HOST_ARGS="$HOST_ARGS $1"
        ;;
    --no-tools)
        NO_TOOLS=1
        ;;
    --wipe-runtimes)
        WIPE_RUNTIMES=1
        ;;
    --clean-runtimes)
        CLEAN_RUNTIMES=1
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
    echo "$0 [--host-clang[=clang]] [--enable-asserts] [--disable-dylib] [--with-clang] [--thinlto] [--full-llvm] [--disable-lldb] [--disable-lldb-mi] [--disable-clang-tools-extra] [--host=triple] [--with-default-win32-winnt=0x601] [--with-default-msvcrt=ucrt] [--enable-cfguard|--disable-cfguard] [--no-runtimes] [--no-tools] [--wipe-runtimes] [--clean-runtimes] dest"
    exit 1
fi

for dep in git cmake ${HOST_CLANG}; do
    if ! command -v $dep >/dev/null; then
        echo "$dep not installed. Please install it and retry" 1>&2
        exit 1
    fi
done

if [ -n "${HOST_CLANG}" ] && [ "${CFGUARD_ARGS}" = "--enable-cfguard"  ]; then
    "${HOST_CLANG}" -c -x c -o - - -Werror -mguard=cf </dev/null >/dev/null 2>/dev/null || CFGUARD_ARGS="--disable-cfguard"
fi

if [ -z "$NO_TOOLS" ]; then
    if [ -z "${HOST_CLANG}" ]; then
        ./build-llvm.sh $PREFIX $LLVM_ARGS $HOST_ARGS
        if [ -z "$NO_LLDB" ] && [ -z "$NO_LLDB_MI" ]; then
            ./build-lldb-mi.sh $PREFIX $HOST_ARGS
        fi
        if [ -z "$FULL_LLVM" ]; then
            ./strip-llvm.sh $PREFIX $HOST_ARGS
        fi
    fi
    ./install-wrappers.sh $PREFIX $HOST_ARGS ${HOST_CLANG:+--host-clang=$HOST_CLANG}
    ./build-mingw-w64-tools.sh $PREFIX $HOST_ARGS
fi
if [ -n "$NO_RUNTIMES" ]; then
    exit 0
fi
if [ -n "$WIPE_RUNTIMES" ]; then
    # Remove the runtime code built previously.
    #
    # This roughly matches the setup as if --no-runtimes had been passed,
    # except that compiler-rt headers are left installed in lib/clang/*/include.
    rm -rf $PREFIX/*-w64-mingw32 $PREFIX/lib/clang/*/lib
fi
if [ -n "$CLEAN_RUNTIMES" ]; then
    export CLEAN=1
fi
./build-mingw-w64.sh $PREFIX $MINGW_ARGS $CFGUARD_ARGS
./build-compiler-rt.sh $PREFIX $CFGUARD_ARGS
./build-libcxx.sh $PREFIX $CFGUARD_ARGS
./build-mingw-w64-libraries.sh $PREFIX $CFGUARD_ARGS
./build-compiler-rt.sh $PREFIX --build-sanitizers # CFGUARD_ARGS intentionally omitted
./build-openmp.sh $PREFIX $CFGUARD_ARGS
