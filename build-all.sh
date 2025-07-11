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

set -ex

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
    --llvm-only)
        LLVM_ONLY=1
        ;;
    --stage1)
        STAGE1=1
        LLVM_ARGS="$LLVM_ARGS --disable-lldb --disable-clang-tools-extra"
        NO_LLDB=1
        ;;
    --profile|--profile=*)
        case "$1" in
        --profile=*)
            INSTRUMENTATION="=${1#*=}"
            ;;
        esac
        PROFILE=1
        LLVM_ARGS="$LLVM_ARGS --disable-lldb --disable-clang-tools-extra --with-clang --disable-dylib --instrumented$INSTRUMENTATION"
        NO_LLDB=1
        LLVM_ONLY=1
        ;;
    --pgo|--pgo=*)
        PGO=1
        LLVM_ARGS="$LLVM_ARGS --with-clang $1"
        ;;
    --full-pgo|--full-pgo=*)
        case "$1" in
        --full-pgo=*)
            INSTRUMENTATION="=${1#*=}"
            ;;
        esac
        PGO=1
        FULL_PGO=1
        ;;
    *)
        if [ -n "$PREFIX" ]; then
            if [ -n "$PREFIX_PGO" ]; then
                echo Unrecognized parameter $1
                exit 1
            fi
            PREFIX_PGO="$1"
        else
            PREFIX="$1"
        fi
        ;;
    esac
    shift
done
if [ -z "$PREFIX" ]; then
    echo "$0 [--host-clang[=clang]] [--enable-asserts] [--disable-dylib] [--with-clang] [--thinlto] [--full-llvm] [--disable-lldb] [--disable-lldb-mi] [--disable-clang-tools-extra] [--host=triple] [--with-default-win32-winnt=0x601] [--with-default-msvcrt=ucrt] [--enable-cfguard|--disable-cfguard] [--no-runtimes] [--llvm-only] [--no-tools] [--wipe-runtimes] [--clean-runtimes] [--stage1] [--profile[=type]] [--pgo[=profile]] [--full-pgo[=type]] dest [pgo-dest]"
    exit 1
fi
if [ -n "$PREFIX_PGO" ] && [ -z "$PGO" ] && [ -z "$FULL_PGO" ]; then
    echo Unrecognized parameter $1
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

if [ -n "$FULL_PGO" ]; then
    if [ -z "$PREFIX_PGO" ]; then
        echo Must provide a second destination for a PGO build
        exit 1
    fi
    ./build-all.sh "$PREFIX" --stage1 $LLVM_ARGS $MINGW_ARGS $CFGUARD_ARGS
    unset COMPILER_LAUNCHER
    ./build-all.sh "$PREFIX" --profile$INSTRUMENTATION $LLVM_ARGS
    ./build-all.sh "$PREFIX" "$PREFIX_PGO" --thinlto --pgo --llvm-only $LLVM_ARGS
    # If one already has a usable profile, one could also do the following
    # two steps only:
    # ./build-all.sh "$PREFIX" --stage1 --llvm-only
    # ./build-all.sh "$PREFIX" "$PREFIX_PGO" --pgo
    exit 0
fi

if [ -n "$PROFILE" ]; then
    export PATH=$PREFIX/bin:$PATH
    STAGE1_PREFIX=$PREFIX
    PREFIX=/tmp/dummy-prefix
elif [ -n "$PGO" ]; then
    if [ -z "$PREFIX_PGO" ]; then
        echo Must provide a second destination for a PGO build
        exit 1
    fi
    export PATH=$PREFIX/bin:$PATH
    STAGE1_PREFIX=$PREFIX
    PREFIX=$PREFIX_PGO

    if [ -n "$LLVM_ONLY" ] && [ "$PREFIX" != "$STAGE1_PREFIX" ] ; then
        # Only rebuilding LLVM, not any runtimes. Copy the stage1 toolchain
        # and rebuild LLVM on top of it.
        rm -rf $PREFIX
        mkdir -p "$(dirname "$PREFIX")"
        cp -a "$STAGE1_PREFIX" "$PREFIX"
        # Remove the native Linux/macOS runtimes which aren't needed in
        # the final distribution.
        rm -rf "$PREFIX"/lib/clang/*/lib/darwin
        rm -rf "$PREFIX"/lib/clang/*/lib/linux
    fi
fi

if [ "$(uname)" = "Darwin" ]; then
    if [ -n "$PROFILE" ] || [ -n "$PGO" ]; then
        # Using a custom Clang, which doesn't find the SDK automatically.
        # CMake sets this automatically, but if using the compiler directly,
        # this is needed. (If compilation uses "cc" or "gcc", it will miss
        # the stage1 llvm-mingw toolchain and use the system compiler anyway.)
        export SDKROOT=$(xcrun --show-sdk-path)
    fi
fi

if [ -z "$NO_TOOLS" ]; then
    if [ -z "${HOST_CLANG}" ]; then
        ./build-llvm.sh $PREFIX $LLVM_ARGS $HOST_ARGS
        if [ -n "$PROFILE" ]; then
            ./pgo-training.sh llvm-project/llvm/build-instrumented $STAGE1_PREFIX
            exit 0
        fi
        if [ -z "$NO_LLDB" ] && [ -z "$NO_LLDB_MI" ]; then
            ./build-lldb-mi.sh $PREFIX $HOST_ARGS
        fi
        if [ -z "$FULL_LLVM" ]; then
            ./strip-llvm.sh $PREFIX $HOST_ARGS
        fi
        if [ -n "$STAGE1" ]; then
            if [ "$(uname)" = "Darwin" ]; then
                ./build-llvm.sh $PREFIX --macos-native-tools
            fi
            # Build runtimes. On Linux, this is needed for profiling.
            # On macOS, it is also needed for OS availability helpers like
            # __isPlatformVersionAtLeast.
            ./build-compiler-rt.sh --native $PREFIX
        fi
    fi
    if [ -n "$LLVM_ONLY" ]; then
        exit 0
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
