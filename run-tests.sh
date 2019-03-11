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
TESTS_ASAN="stacksmash"
TESTS_UBSAN="ubsan"
for arch in $ARCHS; do
    TEST_DIR="$arch"
    mkdir -p $TEST_DIR
    for test in $TESTS_C; do
        $arch-w64-mingw32-clang $test.c -o $TEST_DIR/$test.exe
    done
    for test in $TESTS_C_DLL; do
        $arch-w64-mingw32-clang $test.c -shared -o $TEST_DIR/$test.dll -Wl,--out-implib,$TEST_DIR/lib$test.dll.a
    done
    for test in $TESTS_C_LINK_DLL; do
        $arch-w64-mingw32-clang $test.c -o $TEST_DIR/$test.exe -L$TEST_DIR -l${test%-main}-lib
    done
    TESTS_EXTRA=""
    for test in $TESTS_C_NO_BUILTIN; do
        $arch-w64-mingw32-clang $test.c -o $TEST_DIR/$test-no-builtin.exe -fno-builtin
        TESTS_EXTRA="$TESTS_EXTRA $test-no-builtin"
    done
    for test in $TESTS_CPP; do
        $arch-w64-mingw32-clang++ $test.cpp -o $TEST_DIR/$test.exe
    done
    for test in $TESTS_CPP_DLL; do
        $arch-w64-mingw32-clang++ $test.cpp -shared -o $TEST_DIR/$test.dll
    done
    for test in $TESTS_SSP; do
        $arch-w64-mingw32-clang $test.c -o $TEST_DIR/$test.exe -fstack-protector-strong
    done
    # These aren't run, since asan doesn't work within wine.
    for test in $TESTS_ASAN; do
        case $arch in
        # Sanitizers on windows only support x86.
        i686|x86_64) ;;
        *) continue ;;
        esac
        $arch-w64-mingw32-clang $test.c -o $TEST_DIR/$test-asan.exe -fsanitize=address -g -gcodeview -Wl,-pdb,$arch/$test-asan.pdb
    done
    for test in $TESTS_UBSAN; do
        case $arch in
        # Ubsan might not require anything too x86 specific, but we don't
        # build any of the sanitizer libs for anything else than x86.
        i686|x86_64) ;;
        *) continue ;;
        esac
        $arch-w64-mingw32-clang $test.c -o $TEST_DIR/$test.exe -fsanitize=undefined
        TESTS_EXTRA="$TESTS_EXTRA $test"
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
    compiler_rt_arch=$arch
    if [ "$arch" = "i686" ]; then
        compiler_rt_arch=i386
    fi
    for i in libc++ libunwind libssp-0 libclang_rt.asan_dynamic-$compiler_rt_arch; do
        if [ -f $PREFIX/$arch-w64-mingw32/bin/$i.dll ]; then
            cp $PREFIX/$arch-w64-mingw32/bin/$i.dll $TEST_DIR
            DLL="$DLL $i"
        fi
    done
    cd $TEST_DIR
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
