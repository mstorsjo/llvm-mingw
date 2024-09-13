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
unset HOST_CLANG

while [ $# -gt 0 ]; do
    case "$1" in
    --host-clang|--host-clang=*)
        HOST_CLANG=${1#--host-clang}
        HOST_CLANG=${HOST_CLANG#=}
        HOST_CLANG=${HOST_CLANG:-clang}
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
    echo $0 [--host=triple] [--host-clang[=clang]] dest
    exit 1
fi
mkdir -p "$PREFIX"
PREFIX="$(cd "$PREFIX" && pwd)"

: ${ARCHS:=${TOOLCHAIN_ARCHS-i386 x86_64 arm aarch64 powerpc64le riscv64}}

if [ -n "$HOST" ] && [ -z "$CC" ]; then
    CC=$HOST-gcc
fi
: ${CC:=cc}

if [ -n "$HOST" ]; then
    case $HOST in
    *-mingw32)
        EXEEXT=.exe
        ;;
    esac
else
    case $(uname) in
    MINGW*)
        EXEEXT=.exe
        ;;
    esac
fi

if [ -n "${HOST_CLANG}" ]; then
    HOST_CLANG_EXE=$(command -v $HOST_CLANG)
    HOST_CLANG_VER=$(echo "__clang_major__ __clang_minor__ __clang_patchlevel__" | $HOST_CLANG_EXE -E -P -x c - | xargs printf '%d.%d.%d')

    mkdir -p $PREFIX/bin

    # ex. /usr/lib/llvm-17/lib/clang/17
    resdir=$($HOST_CLANG -print-resource-dir)
    # ex. /usr/lib/llvm-17
    llvmdir=${resdir%/lib/clang/*}
    # ex /lib/clang/17
    clangres=${resdir#$llvmdir}

    mkdir -p $PREFIX$clangres

    # link the header directory, prevent modification
    ln -snf $resdir/include $PREFIX$clangres/include

    # Note: clang will detect the "InstalledDir" based on the path that was used to invoke the tools
    # This might still have some hidden effects
    printf '#!/bin/sh\nsr=$(dirname "$(dirname "$(readlink -f "$0")")")\nexec %s -resource-dir="$sr"%s --sysroot="$sr" "$@"\n' "$HOST_CLANG_EXE" "$clangres" > $PREFIX/bin/clang
    # printf '#!/bin/sh\nsr=$(dirname "$(dirname "$(readlink -f "$0")")")\nexec %s -resource-dir="$sr"%s --sysroot="$sr" "$@"\n' "$(readlink -f "$HOST_CLANG_EXE")" "$clangres" > $PREFIX/bin/clang
    chmod 755 $PREFIX/bin/clang
    ln -sf clang $PREFIX/bin/clang++
    ln -sf clang $PREFIX/bin/clang-cpp

    echo "Using existing clang $HOST_CLANG_EXE ($HOST_CLANG_VER)"
    $PREFIX/bin/clang -v

    # prefer system llvm installation, but search in llvm private paths (eg. debian does not symlink all tools into /usr/bin)
    llvmexec="$PATH:$llvmdir/bin"

    for exec in ld.lld llvm-ar llvm-ranlib llvm-nm llvm-objcopy llvm-strip llvm-rc llvm-cvtres \
                llvm-addr2line llvm-dlltool llvm-readelf llvm-size llvm-strings llvm-addr2line llvm-windres llvm-ml; do
        execpath=$(PATH=$llvmexec command -v $exec) && ln -sf $execpath $PREFIX/bin/$exec
    done
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
    WRAPPER_FLAGS="$WRAPPER_FLAGS -DCLANG_SCAN_DEPS=\"clang-scan-deps-real\""
    # The wrappers may use printf, but doesn't use anything that specifically
    # needs full ansi compliance - prefer leaner binaries by using the CRT
    # implementations.
    WRAPPER_FLAGS="$WRAPPER_FLAGS -D__USE_MINGW_ANSI_STDIO=0"
fi

mkdir -p "$PREFIX/bin"
cp wrappers/*-wrapper.sh "$PREFIX/bin"
cp wrappers/musl-common.cfg "$PREFIX/bin"
for arch in $ARCHS; do
    cp wrappers/$arch*.cfg $PREFIX/bin
done
if [ -n "$HOST" ] && [ -n "$EXEEXT" ]; then
    # TODO: If building natively on msys, pick up the default HOST value from there.
    WRAPPER_FLAGS="$WRAPPER_FLAGS -DDEFAULT_TARGET=\"$HOST\""
    for i in wrappers/*-wrapper.sh; do
        cat $i | sed 's/^DEFAULT_TARGET=.*/DEFAULT_TARGET='$HOST/ > "$PREFIX/bin/$(basename $i)"
    done
fi
$CC wrappers/clang-target-wrapper.c -o "$PREFIX/bin/clang-target-wrapper$EXEEXT" -O2 -Wl,-s $WRAPPER_FLAGS
$CC wrappers/clang-scan-deps-wrapper.c -o "$PREFIX/bin/clang-scan-deps-wrapper$EXEEXT" -O2 -Wl,-s $WRAPPER_FLAGS
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
    triple=$arch-linux-musl
    case $arch in
    arm*)
        triple=$arch-linux-musleabihf
        ;;
    esac
    for exec in clang clang++ gcc g++ c++ as; do
        ln -sf clang-target-wrapper$CTW_SUFFIX $triple-$exec$CTW_LINK_SUFFIX
    done
    for exec in addr2line ar ranlib nm objcopy objdump readelf size strings strip llvm-ar llvm-ranlib; do
        if [ -n "$EXEEXT" ]; then
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
        ln -sf $link_target$EXEEXT $triple-$exec$EXEEXT || true
    done
    for exec in ld; do
        ln -sf $exec-wrapper.sh $triple-$exec
    done
done
if [ -n "$EXEEXT" ]; then
    if [ ! -L clang$EXEEXT ] && [ -f clang$EXEEXT ] && [ ! -f clang-$CLANG_MAJOR$EXEEXT ]; then
        mv clang$EXEEXT clang-$CLANG_MAJOR$EXEEXT
    fi
    if [ ! -L clang-scan-deps$EXEEXT ] && [ -f clang-scan-deps$EXEEXT ] && [ ! -f clang-scan-deps-real$EXEEXT ]; then
        mv clang-scan-deps$EXEEXT clang-scan-deps-real$EXEEXT
    fi
fi
