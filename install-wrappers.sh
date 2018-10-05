#!/bin/sh

set -e

if [ $# -lt 1 ]; then
    echo $0 dest
    exit 1
fi
PREFIX="$1"

: ${ARCHS:=${TOOLCHAIN_ARCHS-i686 x86_64 armv7 aarch64}}

if [ -n "$HOST" ] && [ -z "$CC" ]; then
    CC=$HOST-gcc
fi
: ${CC:=cc}

case $(uname) in
MINGW*)
    EXEEXT=.exe
    ;;
esac

if [ -n "$EXEEXT" ]; then
    CLANG_MAJOR=$(basename $(echo $PREFIX/lib/clang/* | awk '{print $NF}') | cut -f 1 -d .)
    CTW_FLAGS="$CTW_FLAGS -municode -DCLANG=\"clang-$CLANG_MAJOR\""
fi

mkdir -p $PREFIX/bin
cp wrappers/*-wrapper.sh $PREFIX/bin
if [ -n "$HOST" ]; then
    # TODO: If building natively on msys, pick up the default HOST value from there.
    CTW_FLAGS="$CTW_FLAGS -DDEFAULT_TARGET=\"$HOST\""
    for i in wrappers/*-wrapper.sh; do
        cat $i | sed 's/^DEFAULT_TARGET=.*/DEFAULT_TARGET='$HOST/ > $PREFIX/bin/$(basename $i)
    done
fi
$CC wrappers/change-pe-arch.c -o $PREFIX/bin/change-pe-arch$EXEEXT
$CC wrappers/clang-target-wrapper.c -o $PREFIX/bin/clang-target-wrapper$EXEEXT -O2 -Wl,-s $CTW_FLAGS
if [ -n "$EXEEXT" ]; then
    # For Windows, we should prefer the executable wrapper, which also works
    # when invoked from outside of MSYS.
    CTW_SUFFIX=$EXEEXT
    CTW_LINK_SUFFIX=$EXEEXT
else
    CTW_SUFFIX=.sh
fi
cd $PREFIX/bin
for arch in $ARCHS; do
    for exec in clang clang++ gcc g++; do
        ln -sf clang-target-wrapper$CTW_SUFFIX $arch-w64-mingw32-$exec$CTW_LINK_SUFFIX
    done
    for exec in ar ranlib nm strings; do
        ln -sf llvm-$exec$EXEEXT $arch-w64-mingw32-$exec$EXEEXT || true
    done
    for exec in ld objdump windres dlltool; do
        ln -sf $exec-wrapper.sh $arch-w64-mingw32-$exec
    done
    for exec in objcopy strip; do
        ln -sf objcopy-wrapper.sh $arch-w64-mingw32-$exec
    done
done
if [ -n "$EXEEXT" ]; then
    if [ ! -L clang$EXEEXT ]; then
        mv clang$EXEEXT clang-$CLANG_MAJOR$EXEEXT
    fi
fi
