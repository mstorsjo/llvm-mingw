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

DEFAULT_OSES="mingw32 mingw32uwp"
cat<<EOF > is-ucrt.c
#include <corecrt.h>
#if __MSVCRT_VERSION__ < 0x1400 && !defined(_UCRT)
#error not ucrt
#endif
EOF
ANY_ARCH=$(echo $ARCHS | awk '{print $1}')
if ! $ANY_ARCH-w64-mingw32-gcc -E is-ucrt.c > /dev/null 2>&1; then
    # If the default CRT isn't UCRT, we can't build for mingw32uwp.
    DEFAULT_OSES="mingw32"
fi

: ${TARGET_OSES:=${TOOLCHAIN_TARGET_OSES-$DEFAULT_OSES}}

if [ -z "$RUN_X86" ]; then
    case $(uname) in
    MINGW*|MSYS*)
        # A non-empty string to trigger running, even if no wrapper is needed.
        NATIVE_X86=1
        RUN_X86=" "
        export PATH=.:$PATH
        ;;
    *)
        RUN_X86=wine
        ;;
    esac
fi


TESTS_C="hello hello-tls crt-test setjmp"
TESTS_C_DLL="autoimport-lib"
TESTS_C_LINK_DLL="autoimport-main"
TESTS_C_NO_BUILTIN="crt-test"
TESTS_CPP="hello-cpp"
TESTS_CPP_LOAD_DLL="tlstest-main"
TESTS_CPP_EXCEPTIONS="hello-exception exception-locale exception-reduced"
TESTS_CPP_DLL="tlstest-lib"
TESTS_SSP="stacksmash"
TESTS_ASAN="stacksmash"
TESTS_UBSAN="ubsan"
TESTS_UWP="uwp-error"
for arch in $ARCHS; do
    case $arch in
    i686|x86_64)
        RUN="$RUN_X86"
        COPY=
        NATIVE="$NATIVE_X86"
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

    for target_os in $TARGET_OSES; do
        TEST_DIR="$arch-$target_os"
        mkdir -p $TEST_DIR
        for test in $TESTS_C; do
            $arch-w64-$target_os-clang $test.c -o $TEST_DIR/$test.exe
        done
        for test in $TESTS_C_DLL; do
            $arch-w64-$target_os-clang $test.c -shared -o $TEST_DIR/$test.dll -Wl,--out-implib,$TEST_DIR/lib$test.dll.a
        done
        for test in $TESTS_C_LINK_DLL; do
            $arch-w64-$target_os-clang $test.c -o $TEST_DIR/$test.exe -L$TEST_DIR -l${test%-main}-lib
        done
        TESTS_EXTRA=""
        for test in $TESTS_C_NO_BUILTIN; do
            $arch-w64-$target_os-clang $test.c -o $TEST_DIR/$test-no-builtin.exe -fno-builtin
            TESTS_EXTRA="$TESTS_EXTRA $test-no-builtin"
        done
        for test in $TESTS_CPP $TESTS_CPP_EXCEPTIONS; do
            $arch-w64-$target_os-clang++ $test.cpp -o $TEST_DIR/$test.exe
        done
        for test in $TESTS_CPP_EXCEPTIONS; do
            $arch-w64-$target_os-clang++ $test.cpp -O2 -o $TEST_DIR/$test-opt.exe
        done
        if [ "$arch" != "aarch64" ] || [ -n "$NATIVE_AARCH64" ]; then
            for test in $TESTS_CPP_EXCEPTIONS; do
                TESTS_EXTRA="$TESTS_EXTRA $test $test-opt"
            done
        fi
        for test in $TESTS_CPP_LOAD_DLL; do
            case $target_os in
            # DLLs can't be loaded without a Windows package
            mingw32uwp) continue ;;
            *) ;;
            esac
            $arch-w64-$target_os-clang++ $test.cpp -o $TEST_DIR/$test.exe
            TESTS_EXTRA="$TESTS_EXTRA $test"
        done
        for test in $TESTS_CPP_DLL; do
            $arch-w64-$target_os-clang++ $test.cpp -shared -o $TEST_DIR/$test.dll
        done
        for test in $TESTS_SSP; do
            $arch-w64-$target_os-clang $test.c -o $TEST_DIR/$test.exe -fstack-protector-strong
        done
        for test in $TESTS_UWP; do
            set +e
            # compilation should fail for UWP and WinRT
            $arch-w64-$target_os-clang $test.c -o $TEST_DIR/$test.exe -Wimplicit-function-declaration -Werror
            UWP_ERROR=$?
            set -e
            case $target_os in
            mingw32uwp)
                if [ $UWP_ERROR -eq 0 ]; then
                    echo "UWP compilation should have failed for test $test!"
                    exit 1
                fi
                ;;
            *)
                if [ $UWP_ERROR -eq 0 ]; then
                    TESTS_EXTRA="$TESTS_EXTRA $test"
                else
                    echo "$test failed to compile for non-UWP target!"
                    exit 1
                fi
                ;;
            esac
        done
        for test in $TESTS_ASAN; do
            case $arch in
            # Sanitizers on windows only support x86.
            i686|x86_64) ;;
            *) continue ;;
            esac
            $arch-w64-$target_os-clang $test.c -o $TEST_DIR/$test-asan.exe -fsanitize=address -g -gcodeview -Wl,-pdb,$TEST_DIR/$test-asan.pdb
            # Only run these tests on native windows; asan doesn't run in wine.
            if [ -n "$NATIVE" ]; then
                TESTS_EXTRA="$TESTS_EXTRA $test"
            fi
        done
        for test in $TESTS_UBSAN; do
            case $arch in
            # Ubsan might not require anything too x86 specific, but we don't
            # build any of the sanitizer libs for anything else than x86.
            i686|x86_64) ;;
            *) continue ;;
            esac
            $arch-w64-$target_os-clang $test.c -o $TEST_DIR/$test.exe -fsanitize=undefined
            TESTS_EXTRA="$TESTS_EXTRA $test"
        done
        DLL="$TESTS_C_DLL $TESTS_CPP_DLL"
        compiler_rt_arch=$arch
        if [ "$arch" = "i686" ]; then
            compiler_rt_arch=i386
        fi
        if [ "$target_os" != "mingw32" ]; then
            # The Windows Store specific CRT DLL is usually not available
            # outside of such contexts, so skip trying to run those tests.
            continue
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
done
echo All tests succeeded
