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

unset HOST

while [ $# -gt 0 ]; do
    case "$1" in
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
    echo $0 [--host=triple] dest
    exit 1
fi
mkdir -p "$PREFIX"
PREFIX="$(cd "$PREFIX" && pwd)"

: ${ARCHS:=${TOOLCHAIN_ARCHS-i686 x86_64 armv7 aarch64}}
: ${TARGET_OSES:=${TOOLCHAIN_TARGET_OSES-mingw32 mingw32uwp}}

if [ -n "$HOST" ] && [ -z "$CC" ]; then
    CC=$HOST-gcc
fi
: ${CC:=cc}

case $(uname) in
MINGW*)
    EXEEXT=.exe
    ;;
esac

if [ -n "$HOST" ]; then
    EXEEXT=.exe
fi

if [ -n "$MACOS_REDIST" ]; then
    : ${MACOS_REDIST_ARCHS:=arm64 x86_64}
    : ${MACOS_REDIST_VERSION:=10.9}
    for arch in $MACOS_REDIST_ARCHS; do
        WRAPPER_FLAGS="$WRAPPER_FLAGS -arch $arch"
    done
    WRAPPER_FLAGS="$WRAPPER_FLAGS -mmacosx-version-min=$MACOS_REDIST_VERSION"
fi

if [ -n "$EXEEXT" ]; then
    CLANG_MAJOR=$(basename $(echo $PREFIX/lib/clang/* | awk '{print $NF}') | cut -f 1 -d .)
    WRAPPER_FLAGS="$WRAPPER_FLAGS -municode -DCLANG=\"clang-$CLANG_MAJOR\""
fi

mkdir -p "$PREFIX/bin"
cp wrappers/*-wrapper.sh "$PREFIX/bin"
if [ -n "$HOST" ]; then
    # TODO: If building natively on msys, pick up the default HOST value from there.
    WRAPPER_FLAGS="$WRAPPER_FLAGS -DDEFAULT_TARGET=\"$HOST\""
    for i in wrappers/*-wrapper.sh; do
        cat $i | sed 's/^DEFAULT_TARGET=.*/DEFAULT_TARGET='$HOST/ > "$PREFIX/bin/$(basename $i)"
    done
fi
$CC wrappers/clang-target-wrapper.c -o "$PREFIX/bin/clang-target-wrapper$EXEEXT" -O2 -Wl,-s $WRAPPER_FLAGS
$CC wrappers/llvm-wrapper.c -o "$PREFIX/bin/llvm-wrapper$EXEEXT" -O2 -Wl,-s $WRAPPER_FLAGS
if [ -n "$EXEEXT" ]; then
    # For Windows, we should prefer the executable wrapper, which also works
    # when invoked from outside of MSYS.
    CTW_SUFFIX=$EXEEXT
    CTW_LINK_SUFFIX=$EXEEXT
else
    CTW_SUFFIX=.sh
fi
cd "$PREFIX/bin"
for arch in $ARCHS; do
    for target_os in $TARGET_OSES; do
        for exec in clang clang++ gcc g++ c++ as; do
            ln -sf clang-target-wrapper$CTW_SUFFIX $arch-w64-$target_os-$exec$CTW_LINK_SUFFIX
        done
        for exec in addr2line ar ranlib nm objcopy readelf size strings strip llvm-ar llvm-ranlib; do
            if [ -n "$HOST" ]; then
                link_target=llvm-wrapper
            else
                case $exec in
                llvm-*)
                    link_target=$exec
                    ;;
                *)
                    link_target=llvm-$exec
                    ;;
                esac
            fi
            ln -sf $link_target$EXEEXT $arch-w64-$target_os-$exec$EXEEXT || true
        done
        # windres and dlltool can't use llvm-wrapper, as that loses the original
        # target arch prefix.
        ln -sf llvm-windres$EXEEXT $arch-w64-$target_os-windres$EXEEXT
        ln -sf llvm-dlltool$EXEEXT $arch-w64-$target_os-dlltool$EXEEXT
        for exec in ld objdump; do
            ln -sf $exec-wrapper.sh $arch-w64-$target_os-$exec
        done
    done
done
if [ -n "$EXEEXT" ]; then
    if [ ! -L clang$EXEEXT ] && [ -f clang$EXEEXT ] && [ ! -f clang-$CLANG_MAJOR$EXEEXT ]; then
        mv clang$EXEEXT clang-$CLANG_MAJOR$EXEEXT
    fi
    if [ -z "$HOST" ]; then
        HOST=$(./clang-$CLANG_MAJOR -dumpmachine | sed 's/-.*//')-w64-mingw32
    fi
    HOST_ARCH="${HOST%%-*}"
    # Install unprefixed wrappers if $HOST is one of the architectures
    # we are installing wrappers for.
    case $ARCHS in
    *$HOST_ARCH*)
        for exec in clang clang++ gcc g++ c++ addr2line ar dlltool ranlib nm objcopy readelf size strings strip windres; do
            ln -sf $HOST-$exec$EXEEXT $exec$EXEEXT
        done
        for exec in cc c99 c11; do
            ln -sf clang$EXEEXT $exec$EXEEXT
        done
        for exec in ld objdump; do
            ln -sf $HOST-$exec $exec
        done
        ;;
    esac
fi
