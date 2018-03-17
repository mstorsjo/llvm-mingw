#!/bin/sh

set -ex

if [ $# -lt 1 ]; then
    echo $0 dest
    exit 1
fi
PREFIX="$1"
export PATH=$PREFIX/bin:$PATH

: ${ARCHS:=${TOOLCHAIN_ARCHS-i686 x86_64 armv7 aarch64}}

cd hello
for arch in $ARCHS; do
    $arch-w64-mingw32-clang hello.c -o hello-$arch.exe
    $arch-w64-mingw32-clang hello-tls.c -o hello-tls-$arch.exe
    $arch-w64-mingw32-clang++ hello.cpp -o hello-cpp-$arch.exe -fno-exceptions
    $arch-w64-mingw32-clang++ hello-exception.cpp -o hello-exception-$arch.exe
    case $arch in
    i686|x86_64)
        RUN=wine
        COPY=
        ;;
    armv7)
        RUN="$RUN_ARMV7"
        COPY="$COPY_ARMV7"
        ;;
    aarch64)
        RUN="$RUN_AARCH64"
        COPY="$COPY_AARCH64"
        ;;
    esac
    for file in hello-$arch.exe hello-tls-$arch.exe hello-cpp-$arch.exe hello-exception-$arch.exe; do
        if [ -n "$COPY" ]; then
            $COPY $file
        fi
        if [ -n "$RUN" ]; then
            $RUN $file
        fi
    done
done
