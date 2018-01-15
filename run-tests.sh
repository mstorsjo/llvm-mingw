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
    if [ "$arch" = "i686" ] || [ "$arch" = "x86_64" ]; then
        wine hello-$arch.exe
        wine hello-tls-$arch.exe
        wine hello-cpp-$arch.exe
        wine hello-exception-$arch.exe
    fi
done
