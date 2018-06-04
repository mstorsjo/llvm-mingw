#!/bin/sh

set -ex

if [ $# -lt 1 ]; then
    echo $0 dest
    exit 1
fi
PREFIX="$1"
export PATH=$PREFIX/bin:$PATH

: ${ARCHS:=${TOOLCHAIN_ARCHS-i686 x86_64 armv7 aarch64}}

cd test
TESTS_C="hello hello-tls crt-test"
TESTS_C_NO_BUILTIN="crt-test"
TESTS_CPP="hello-cpp hello-exception"
for arch in $ARCHS; do
    for test in $TESTS_C; do
        $arch-w64-mingw32-clang $test.c -o $test-$arch.exe
    done
    TESTS_EXTRA=""
    for test in $TESTS_C_NO_BUILTIN; do
        $arch-w64-mingw32-clang $test.c -o $test-no-builtin-$arch.exe -fno-builtin
        TESTS_EXTRA="$TESTS_EXTRA $test-no-builtin"
    done
    for test in $TESTS_CPP; do
        $arch-w64-mingw32-clang++ $test.cpp -o $test-$arch.exe
    done
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
    for test in $TESTS_C $TESTS_CPP $TESTS_EXTRA; do
        file=$test-$arch.exe
        if [ -n "$COPY" ]; then
            $COPY $file
        fi
        if [ -n "$RUN" ]; then
            $RUN $file
        fi
    done
done
