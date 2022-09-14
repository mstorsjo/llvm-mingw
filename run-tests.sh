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
PREFIX="$(cd "$PREFIX" && pwd)"
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
rm -f is-ucrt.c

if (echo "int main(){}" | $ANY_ARCH-w64-mingw32-clang -x c++ - -o has-cfguard-test.exe -mguard=cf); then
    if llvm-readobj --coff-load-config has-cfguard-test.exe | grep -q 'CF_INSTRUMENTED (0x100)'; then
        HAS_CFGUARD=1
    elif [ -n "$HAS_CFGUARD" ]; then
        echo "error: Toolchain doesn't seem to include Control Flow Guard support." 1>&2
        rm -f has-cfguard-test.exe
        exit 1
    fi
    rm -f has-cfguard-test.exe
elif [ -n "$HAS_CFGUARD" ]; then
    echo "error: Toolchain doesn't seem to include Control Flow Guard support." 1>&2
    exit 1
fi

: ${TARGET_OSES:=${TOOLCHAIN_TARGET_OSES-$DEFAULT_OSES}}

if [ -z "$RUN_X86_64" ] && [ -z "$RUN_I686" ]; then
    case $(uname) in
    MINGW*|MSYS*)
        NATIVE_X86=1
        # A non-empty string to trigger running, even if no wrapper is needed.
        RUN_X86_64=" "
        RUN_I686=" "
        export PATH=.:$PATH
        ;;
    *)
        case $(uname -m) in
        x86_64)
            : ${RUN_X86_64:=wine}
            : ${RUN_I686:=wine}
            ;;
        esac
        ;;
    esac
fi


TESTS_C="hello hello-tls crt-test setjmp"
TESTS_C_DLL="autoimport-lib"
TESTS_C_LINK_DLL="autoimport-main"
TESTS_C_NO_BUILTIN="crt-test"
TESTS_C_ANSI_STDIO="crt-test"
TESTS_CPP="hello-cpp global-terminate tlstest-main longjmp-cleanup"
TESTS_CPP_EXCEPTIONS="hello-exception exception-locale exception-reduced"
TESTS_CPP_STATIC="hello-exception"
TESTS_CPP_DLL="tlstest-lib throwcatch-lib"
TESTS_CPP_LINK_DLL="throwcatch-main"
TESTS_SSP="stacksmash"
TESTS_ASAN="stacksmash"
TESTS_FORTIFY="bufferoverflow crt-test"
TESTS_UBSAN="ubsan"
TESTS_OMP="hello-omp"
TESTS_UWP="uwp-error"
TESTS_IDL="idltest"
TESTS_OTHER_TARGETS="hello"
if [ -n "$HAS_CFGUARD" ]; then
    TESTS_CFGUARD="cfguard-test"
fi
for arch in $ARCHS; do
    case $arch in
    i686)
        RUN="$RUN_I686"
        COPY="$COPY_I686"
        NATIVE="$NATIVE_X86"
        ;;
    x86_64)
        RUN="$RUN_X86_64"
        COPY="$COPY_X86_64"
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
    TESTS_EXTRA=""
    FAILURE_TESTS=""
    [ -z "$CLEAN" ] || rm -rf $TEST_DIR
    # A leftover libc++.dll from a previous round will cause the linker to find it (and error out) instead of
    # locating libc++.dll.a in a later include directory. The same goes with
    # libunwind.dll.
    rm -f $TEST_DIR/libc++.dll $TEST_DIR/libunwind.dll
    mkdir -p $TEST_DIR
    for test in $TESTS_C; do
        $arch-w64-mingw32-clang $test.c -o $TEST_DIR/$test.exe
    done
    for target_os in $TARGET_OSES; do
        # Check that some generic tests build successfully for other targets.
        # These tests are included in other groups, so skip the for the default
        # mingw32 target, only test them for e.g. UWP.
        if [ "$target_os" = "mingw32" ]; then
            continue
        fi
        for test in $TESTS_OTHER_TARGETS; do
            $arch-w64-$target_os-clang $test.c -o $TEST_DIR/$test-$target_os.exe
            TESTS_EXTRA="$TESTS_EXTRA $test-$target_os"
        done
    done
    for test in $TESTS_C_DLL; do
        $arch-w64-mingw32-clang $test.c -shared -o $TEST_DIR/$test.dll -Wl,--out-implib,$TEST_DIR/lib$test.dll.a
    done
    for test in $TESTS_C_LINK_DLL; do
        $arch-w64-mingw32-clang $test.c -o $TEST_DIR/$test.exe -L$TEST_DIR -l${test%-main}-lib
    done
    for test in $TESTS_C_NO_BUILTIN; do
        $arch-w64-mingw32-clang $test.c -o $TEST_DIR/$test-no-builtin.exe -fno-builtin
        TESTS_EXTRA="$TESTS_EXTRA $test-no-builtin"
    done
    for test in $TESTS_C_ANSI_STDIO; do
        $arch-w64-mingw32-clang $test.c -o $TEST_DIR/$test-ansi-stdio.exe -D__USE_MINGW_ANSI_STDIO=1
        TESTS_EXTRA="$TESTS_EXTRA $test-ansi-stdio"
    done
    for test in $TESTS_CPP; do
        $arch-w64-mingw32-clang++ $test.cpp -o $TEST_DIR/$test.exe
    done
    for test in $TESTS_CPP_EXCEPTIONS; do
        $arch-w64-mingw32-clang++ $test.cpp -o $TEST_DIR/$test.exe
        $arch-w64-mingw32-clang++ $test.cpp -O2 -o $TEST_DIR/$test-opt.exe
        TESTS_EXTRA="$TESTS_EXTRA $test $test-opt"
    done
    for test in $TESTS_CPP_STATIC; do
        $arch-w64-mingw32-clang++ $test.cpp -static -o $TEST_DIR/$test-static.exe
        TESTS_EXTRA="$TESTS_EXTRA $test-static"
    done
    for test in $TESTS_CPP_DLL; do
        $arch-w64-mingw32-clang++ $test.cpp -shared -o $TEST_DIR/$test.dll -Wl,--out-implib,$TEST_DIR/lib$test.dll.a
    done
    for test in $TESTS_CPP_LINK_DLL; do
        $arch-w64-mingw32-clang++ $test.cpp -o $TEST_DIR/$test.exe -L$TEST_DIR -l${test%-main}-lib
    done
    for test in $TESTS_SSP; do
        $arch-w64-mingw32-clang $test.c -o $TEST_DIR/$test.exe -fstack-protector-strong
        FAILURE_TESTS="$FAILURE_TESTS $test"
    done
    for test in $TESTS_CFGUARD; do
        $arch-w64-mingw32-clang $test.c -o $TEST_DIR/$test.exe -mguard=cf
    done
    for test in $TESTS_FORTIFY; do
        $arch-w64-mingw32-clang $test.c -o $TEST_DIR/$test-fortify.exe -O2 -D_FORTIFY_SOURCE=2
        TESTS_EXTRA="$TESTS_EXTRA $test-fortify"
        if [ "$test" != "crt-test" ]; then
            # crt-test doesn't trigger failures
            FAILURE_TESTS="$FAILURE_TESTS $test-fortify"
        fi
    done
    for test in $TESTS_IDL; do
        # This is primary a build-only test, so no need to execute it.
        # The IDL output isn't arch specific, but we want to test the
        # individual widl frontends.
        $arch-w64-mingw32-widl $test.idl -h -o $TEST_DIR/$test.h
        $arch-w64-mingw32-clang $test.c -I$TEST_DIR -o $TEST_DIR/$test.exe -lole32
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
        $arch-w64-mingw32-clang $test.c -o $TEST_DIR/$test-asan.exe -fsanitize=address -g -gcodeview -Wl,--pdb=
        # Only run these tests on native windows; asan doesn't run in wine.
        if [ -n "$NATIVE" ]; then
            TESTS_EXTRA="$TESTS_EXTRA $test-asan"
            FAILURE_TESTS="$FAILURE_TESTS $test-asan"
        fi
        if [ -n "$HAS_CFGUARD" ]; then
            # Smoke test ASAN with CFGuard to make sure it doesn't trip.
            $arch-w64-mingw32-clang $test.c -o $TEST_DIR/$test-asan-cfguard.exe -fsanitize=address -g -gcodeview -Wl,--pdb= -mguard=cf
            if [ -n "$NATIVE" ]; then
                TESTS_EXTRA="$TESTS_EXTRA $test-asan-cfguard"
                FAILURE_TESTS="$FAILURE_TESTS $test-asan-cfguard"
            fi
        fi
    done
    for test in $TESTS_UBSAN; do
        case $arch in
        # Ubsan might not require anything too x86 specific, but we don't
        # build any of the sanitizer libs for anything else than x86.
        i686|x86_64) ;;
        *) continue ;;
        esac
        $arch-w64-mingw32-clang $test.c -o $TEST_DIR/$test.exe -fsanitize=undefined -fno-sanitize-recover=all
        TESTS_EXTRA="$TESTS_EXTRA $test"
        FAILURE_TESTS="$FAILURE_TESTS $test"
    done
    for test in $TESTS_OMP; do
        case $arch in
        # OpenMP on windows only supports x86.
        i686|x86_64) ;;
        *) continue ;;
        esac
        $arch-w64-mingw32-clang $test.c -o $TEST_DIR/$test.exe -fopenmp=libomp
        TESTS_EXTRA="$TESTS_EXTRA $test"
    done
    DLL="$TESTS_C_DLL $TESTS_CPP_DLL"
    compiler_rt_arch=$arch
    if [ "$arch" = "i686" ]; then
        compiler_rt_arch=i386
    fi
    for i in libc++ libunwind libssp-0 libclang_rt.asan_dynamic-$compiler_rt_arch libomp; do
        if [ -f $PREFIX/$arch-w64-mingw32/bin/$i.dll ]; then
            cp $PREFIX/$arch-w64-mingw32/bin/$i.dll $TEST_DIR
            DLL="$DLL $i"
        fi
    done
    RUN_TESTS="$TESTS_C $TESTS_C_LINK_DLL $TESTS_CPP $TESTS_CPP_LINK_DLL $TESTS_EXTRA $TESTS_SSP"
    cd $TEST_DIR
    if [ -n "$COPY" ]; then
        COPYFILES=""
        for i in $DLL; do
            COPYFILES="$COPYFILES $i.dll"
        done
        for i in $RUN_TESTS; do
            COPYFILES="$COPYFILES $i.exe"
        done
        $COPY $COPYFILES
    fi
    if [ -n "$RUN" ] && [ "$RUN" != "false" ]; then
        for test in $RUN_TESTS; do
            file=$test.exe
            $RUN $file
        done

        # These don't strictly require running native instead of in Wine
        # (except for sanitizers, but they are already filtered out at this
        # point), but some of the error situations trigger crashes, which
        # might not work robustly on all exotic Wine configurations - thus
        # only run these tests on native Windows.
        if [ -n "$NATIVE" ]; then
            for test in $FAILURE_TESTS; do
                file=$test.exe
                OUT=cmdoutput
                rm -f $OUT
                if $RUN $file trigger > $OUT 2>&1; then
                    cat $OUT
                    echo $file trigger should have failed
                    exit 1
                else
                    ret=$?
                    cat $OUT
                    echo $file trigger failed expectedly, returned $ret

                    case $test in
                    stacksmash-asan|stacksmash-asan-cfguard)
                        grep -q stack-buffer-overflow $OUT
                        grep -q "func.*stacksmash.c" $OUT
                        ;;
                    ubsan)
                        grep -q "signed integer overflow" $OUT
                        ;;
                    stacksmash)
                        # GNU libssp writes this directly to the console,
                        # and it can't be redirected, so we can't check for its presence.
                        #grep -q "stack smashing detected" $OUT
                        ;;
                    bufferoverflow-*)
                        # GNU libssp writes this directly to the console,
                        # and it can't be redirected, so we can't check for its presence.
                        #grep -q "buffer overflow detected" $OUT
                        ;;
                    *)
                        echo Unhandled failure test $test
                        exit 1
                        ;;
                    esac
                    rm -f $OUT
                fi
            done
            # Run all testcases for the bufferoverflow test.
            file=bufferoverflow-fortify.exe
            OUT=cmdoutput
            i=0
            while [ $i -le 10 ]; do
                rm -f $OUT
                if $RUN $file $i > $OUT 2>&1; then
                    cat $OUT
                    echo $file $i should have failed
                    exit 1
                else
                    ret=$?
                    cat $OUT
                    echo $file $i failed expectedly, returned $ret
                    #grep -q "buffer overflow detected" $OUT
                    rm -f $OUT
                fi
                i=$(($i+1))
            done
            for test in $TESTS_CFGUARD; do
                file=$test.exe
                OUT=cmdoutput
                rm -f $OUT
                if $RUN $test.exe check_enabled; then
                    $RUN $test.exe normal_icall
                    $RUN $test.exe invalid_icall_nocf || [ $? = 2 ]
                    # We want to check the exit code to be 0xc0000409
                    # (STATUS_STACK_BUFFER_OVERRUN aka fail fast exception).
                    # MSYS2 bash does not give us the full 32-bit exit code, so
                    # we have to rely on cmd.exe to perform the check.
                    # (This probably doesn't work on Wine, but Wine doesn't
                    # support CFG anyway, at least not for now...)
                    $RUN cmd //v:on //c "$test.exe invalid_icall & if !errorlevel! equ -1073740791 (exit 0) else (exit 1)"
                fi
            done
        fi
    fi
    cd ..
done
echo All tests succeeded
