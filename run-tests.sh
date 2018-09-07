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
TESTS_C="hello hello-tls crt-test setjmp"
TESTS_C_DLL="autoimport-lib"
TESTS_C_LINK_DLL="autoimport-main"
TESTS_C_NO_BUILTIN="crt-test"
TESTS_CPP="hello-cpp hello-exception tlstest-main exception-locale"
TESTS_CPP_DLL="tlstest-lib"
TESTS_SSP="stacksmash"
for arch in $ARCHS; do
    mkdir -p $arch
    for test in $TESTS_C; do
        $arch-w64-mingw32-clang $test.c -o $arch/$test.exe
    done
    for test in $TESTS_C_DLL; do
        $arch-w64-mingw32-clang $test.c -shared -o $arch/$test.dll -Wl,--out-implib,$arch/lib$test.dll.a
    done
    for test in $TESTS_C_LINK_DLL; do
        $arch-w64-mingw32-clang $test.c -o $arch/$test.exe -L$arch -l${test%-main}-lib
    done
    TESTS_EXTRA=""
    for test in $TESTS_C_NO_BUILTIN; do
        $arch-w64-mingw32-clang $test.c -o $arch/$test-no-builtin.exe -fno-builtin
        TESTS_EXTRA="$TESTS_EXTRA $test-no-builtin"
    done
    for test in $TESTS_CPP; do
        $arch-w64-mingw32-clang++ $test.cpp -o $arch/$test.exe
    done
    for test in $TESTS_CPP_DLL; do
        $arch-w64-mingw32-clang++ $test.cpp -shared -o $arch/$test.dll
    done
    for test in $TESTS_SSP; do
        $arch-w64-mingw32-clang $test.c -o $arch/$test.exe -fstack-protector-strong
    done
    DLL="$TESTS_C_DLL $TESTS_CPP_DLL"
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
    for i in libc++ libunwind libssp-0; do
        if [ -f $PREFIX/$arch-w64-mingw32/bin/$i.dll ]; then
            cp $PREFIX/$arch-w64-mingw32/bin/$i.dll $arch
            DLL="$DLL $i"
        fi
    done
    cd $arch
    if [ -n "$COPY" ]; then
        for i in $DLL; do
            $COPY $i.dll
        done
    fi
    for test in $TESTS_C $TESTS_C_LINK_DLL $TESTS_CPP $TESTS_EXTRA $TESTS_SSP; do
        file=$test.exe
        if [ -n "$COPY" ]; then
            $COPY $file
        fi
        if [ -n "$RUN" ]; then
            $RUN $file
        fi
    done
    cd ..
done
