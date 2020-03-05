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
TESTS_C_ANSI_STDIO="crt-test"
TESTS_CPP="hello-cpp"
TESTS_CPP_LOAD_DLL="tlstest-main"
TESTS_CPP_EXCEPTIONS="hello-exception exception-locale exception-reduced"
TESTS_CPP_DLL="tlstest-lib"
TESTS_SSP="stacksmash"
TESTS_ASAN="stacksmash"
TESTS_UBSAN="ubsan"
TESTS_UWP="uwp-error"
TESTS_OTHER_TARGETS="hello"
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

    TEST_DIR="$arch"
    mkdir -p $TEST_DIR
    for test in $TESTS_C; do
        $arch-w64-mingw32-clang $test.c -o $TEST_DIR/$test.exe
    done
    for target_os in $TARGET_OSES; do
        # Check that some generic tests build successfully for other targets.
        # These tests are included in other groups, so skip the for the default
        # mingw32 target, only test them for e.g. UWP.
        # These tests are only built, not run, because the Windows Store specific
        # CRT DLL isn't usually available outside of such a context.
        if [ "$target_os" = "mingw32" ]; then
            continue
        fi
        for test in $TESTS_OTHER_TARGETS; do
            $arch-w64-$target_os-clang $test.c -o $TEST_DIR/$test-$target_os.exe
        done
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
    for test in $TESTS_C_ANSI_STDIO; do
        $arch-w64-mingw32-clang $test.c -o $TEST_DIR/$test-ansi-stdio.exe -D__USE_MINGW_ANSI_STDIO=1
        TESTS_EXTRA="$TESTS_EXTRA $test-ansi-stdio"
    done
    for test in $TESTS_CPP $TESTS_CPP_EXCEPTIONS; do
        $arch-w64-mingw32-clang++ $test.cpp -o $TEST_DIR/$test.exe
    done
    for test in $TESTS_CPP_EXCEPTIONS; do
        $arch-w64-mingw32-clang++ $test.cpp -O2 -o $TEST_DIR/$test-opt.exe
    done
    if [ "$arch" != "aarch64" ] || [ -n "$NATIVE_AARCH64" ]; then
        for test in $TESTS_CPP_EXCEPTIONS; do
            TESTS_EXTRA="$TESTS_EXTRA $test $test-opt"
        done
    fi
    for test in $TESTS_CPP_LOAD_DLL; do
        $arch-w64-mingw32-clang++ $test.cpp -o $TEST_DIR/$test.exe
        TESTS_EXTRA="$TESTS_EXTRA $test"
    done
    for test in $TESTS_CPP_DLL; do
        $arch-w64-mingw32-clang++ $test.cpp -shared -o $TEST_DIR/$test.dll
    done
    for test in $TESTS_SSP; do
        $arch-w64-mingw32-clang $test.c -o $TEST_DIR/$test.exe -fstack-protector-strong
    done
    for target_os in $TARGET_OSES; do
        for test in $TESTS_UWP; do
            set +e
            # compilation should fail for UWP and WinRT
            $arch-w64-$target_os-clang $test.c -o $TEST_DIR/$test-$target_os.exe -Wimplicit-function-declaration -Werror > /dev/null 2>&1
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
                    TESTS_EXTRA="$TESTS_EXTRA $test-$target_os"
                else
                    echo "$test failed to compile for non-UWP target!"
                    exit 1
                fi
                ;;
            esac
        done
    done
    for test in $TESTS_ASAN; do
        case $arch in
        # Sanitizers on windows only support x86.
        i686|x86_64) ;;
        *) continue ;;
        esac
        $arch-w64-mingw32-clang $test.c -o $TEST_DIR/$test-asan.exe -fsanitize=address -g -gcodeview -Wl,-pdb,$TEST_DIR/$test-asan.pdb
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
        $arch-w64-mingw32-clang $test.c -o $TEST_DIR/$test.exe -fsanitize=undefined
        TESTS_EXTRA="$TESTS_EXTRA $test"
    done
    DLL="$TESTS_C_DLL $TESTS_CPP_DLL"
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
echo All tests succeeded
