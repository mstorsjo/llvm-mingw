#!/bin/sh

set -e

if [ $# -lt 1 ]; then
    echo $0 dest
    exit 1
fi
PREFIX="$1"
mkdir -p "$PREFIX"
PREFIX="$(cd "$PREFIX" && pwd)"

: ${ARCHS:=${TOOLCHAIN_ARCHS-i686 x86_64 armv7 aarch64}}
: ${TARGET_OSES:=${TOOLCHAIN_TARGET_OSES-mingw32 mingw32uwp mingw32winrt}}

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
    WRAPPER_FLAGS="$WRAPPER_FLAGS -municode -DCLANG=\"clang-$CLANG_MAJOR\""
fi

mkdir -p $PREFIX/bin
cp wrappers/*-wrapper.sh $PREFIX/bin
if [ -n "$HOST" ]; then
    # TODO: If building natively on msys, pick up the default HOST value from there.
    WRAPPER_FLAGS="$WRAPPER_FLAGS -DDEFAULT_TARGET=\"$HOST\""
    for i in wrappers/*-wrapper.sh; do
        cat $i | sed 's/^DEFAULT_TARGET=.*/DEFAULT_TARGET='$HOST/ > $PREFIX/bin/$(basename $i)
    done
fi
$CC wrappers/clang-target-wrapper.c -o $PREFIX/bin/clang-target-wrapper$EXEEXT -O2 -Wl,-s $WRAPPER_FLAGS
$CC wrappers/windres-wrapper.c -o $PREFIX/bin/windres-wrapper$EXEEXT -O2 -Wl,-s $WRAPPER_FLAGS
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
    for target_os in $TARGET_OSES; do
        for exec in clang clang++ gcc g++ cc c99 c11 c++; do
            ln -sf clang-target-wrapper$CTW_SUFFIX $arch-w64-$target_os-$exec$CTW_LINK_SUFFIX
        done
        for exec in ar ranlib nm objcopy strings strip; do
            ln -sf llvm-$exec$EXEEXT $arch-w64-$target_os-$exec$EXEEXT || true
        done
        for exec in windres; do
            ln -sf $exec-wrapper$EXEEXT $arch-w64-$target_os-$exec$EXEEXT
        done
        for exec in ld objdump dlltool; do
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
    for exec in clang clang++ gcc g++ cc c99 c11 c++ ar ranlib nm objcopy strings strip widl windres; do
        ln -sf $HOST-$exec$EXEEXT $exec$EXEEXT
    done
    for exec in ld objdump dlltool; do
        ln -sf $HOST-$exec $exec
    done
fi
