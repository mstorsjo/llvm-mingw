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

if [ $# -lt 1 ]; then
    echo $0 dest
    exit 1
fi
PREFIX="$1"
PREFIX="$(cd "$PREFIX" && pwd)"
export PATH=$PREFIX/bin:$PATH

: ${CORES:=$(nproc 2>/dev/null)}
: ${CORES:=$(sysctl -n hw.ncpu 2>/dev/null)}
: ${CORES:=4}
: ${ARCHS:=${TOOLCHAIN_ARCHS-i686 x86_64 armv7 aarch64}}

MAKE=make
if command -v gmake >/dev/null; then
    MAKE=gmake
fi

case $(uname -s) in
Darwin)
    ;;
*)
    # Assume everything except macOS has got GNU make >= 4.0
    MAKEOPTS="-O"
esac

cd test

HAVE_UWP=1
cat<<EOF > is-ucrt.c
#include <corecrt.h>
#if !defined(_UCRT)
#error not ucrt
#endif
EOF
ANY_ARCH=$(echo $ARCHS | awk '{print $1}')
if $ANY_ARCH-w64-mingw32-gcc$TOOLEXT -E is-ucrt.c > /dev/null 2>&1; then
    IS_UCRT=1
else
    # If the default CRT isn't UCRT, we can't build for mingw32uwp.
    unset HAVE_UWP
fi
rm -f is-ucrt.c

if (echo "int main(){}" | $ANY_ARCH-w64-mingw32-gcc$TOOLEXT -x c++ - -o has-cfguard-test.exe -mguard=cf); then
    if llvm-readobj$TOOLEXT --coff-load-config has-cfguard-test.exe | grep -q 'CF_INSTRUMENTED (0x100)'; then
        HAVE_CFGUARD=1
    elif [ -n "$HAVE_CFGUARD" ]; then
        echo "error: Toolchain doesn't seem to include Control Flow Guard support." 1>&2
        rm -f has-cfguard-test.exe
        exit 1
    fi
    rm -f has-cfguard-test.exe
elif [ -n "$HAVE_CFGUARD" ]; then
    echo "error: Toolchain doesn't seem to include Control Flow Guard support." 1>&2
    exit 1
fi

: ${TARGET_OSES:=${TOOLCHAIN_TARGET_OSES-$DEFAULT_OSES}}

if [ -z "$RUN_X86_64" ] && [ -z "$RUN_I686" ]; then
    case $(uname) in
    MINGW*|MSYS*)
        NATIVE_X86=1
        RUN_X86_64=true
        RUN_I686=true
        ;;
    *)
        case $(uname -m) in
        x86_64)
            : ${RUN_X86_64:=wine}
            : ${RUN_I686:=wine}
            ;;
        esac
        ;;
    esac
fi


for arch in $ARCHS; do
    unset HAVE_ASAN
    case $arch in
    i686)
        RUN="$RUN_I686"
        COPY="$COPY_I686"
        NATIVE="$NATIVE_X86"
        if [ -n "$IS_UCRT" ]; then
            HAVE_ASAN=1
        fi
        ;;
    x86_64)
        RUN="$RUN_X86_64"
        COPY="$COPY_X86_64"
        NATIVE="$NATIVE_X86"
        if [ -n "$IS_UCRT" ]; then
            HAVE_ASAN=1
        fi
        ;;
    armv7)
        RUN="$RUN_ARMV7"
        COPY="$COPY_ARMV7"
        NATIVE="$NATIVE_ARMV7"
        ;;
    aarch64)
        RUN="$RUN_AARCH64"
        COPY="$COPY_AARCH64"
        NATIVE="$NATIVE_AARCH64"
        ;;
    esac

    TARGET=all
    if [ -n "$RUN" ] && [ "$RUN" != "false" ]; then
        TARGET=test
        if [ "$RUN" = "true" ]; then
            unset RUN
        fi
    fi
    COPYARG=""
    if [ -n "$COPY" ]; then
        COPYARG="COPY=$COPY"
    fi

    TEST_DIR="$arch"
    [ -z "$CLEAN" ] || rm -rf $TEST_DIR
    mkdir -p $TEST_DIR
    cd $TEST_DIR
    $MAKE -f ../Makefile ARCH=$arch HAVE_UWP=$HAVE_UWP HAVE_CFGUARD=$HAVE_CFGUARD HAVE_ASAN=$HAVE_ASAN NATIVE=$NATIVE RUNTIMES_SRC=$PREFIX/$arch-w64-mingw32/bin clean
    $MAKE -f ../Makefile ARCH=$arch HAVE_UWP=$HAVE_UWP HAVE_CFGUARD=$HAVE_CFGUARD HAVE_ASAN=$HAVE_ASAN NATIVE=$NATIVE RUNTIMES_SRC=$PREFIX/$arch-w64-mingw32/bin RUN="$RUN" $COPYARG $MAKEOPTS -j$CORES $TARGET
    cd ..
done
echo All tests succeeded
