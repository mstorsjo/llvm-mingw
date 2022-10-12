#!/bin/sh
#
# Copyright (c) 2022 Martin Storsjo
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
    echo $0 prefix
    exit 1
fi
PREFIX="$1"
PREFIX="$(cd "$PREFIX" && pwd)"
export PATH=$PREFIX/bin:$PATH

# We use tool names with explicit .exe suffixes here, so that it works both
# in msys2 bash and in bash in WSL.
: ${CXX:=clang++.exe}
: ${LLDB:=lldb.exe}
: ${STRIP:=strip.exe}
: ${OBJCOPY:=objcopy.exe}

TARGET=$(clang.exe --version | grep Target: | awk '{print $2}')
ARCH="${TARGET%%-*}"

cd test

TEST_DIR="$ARCH"
[ -z "$CLEAN" ] || rm -rf $TEST_DIR

mkdir -p $TEST_DIR

# Build an executable with DWARF debug info
$CXX hello-exception.cpp -o $TEST_DIR/hello-exception-dwarf.exe -g

# Build an executable with PDB debug info
$CXX hello-exception.cpp -o $TEST_DIR/hello-exception-pdb.exe -g -gcodeview -Wl,--pdb=
# Strip the executable that uses pdb; the crt startup files and mingw static
# library object files have dwarf debug info, so the binary has got a bit of
# both, and lldb would choose to use the dwarf parts unless we strip it.
$STRIP $TEST_DIR/hello-exception-pdb.exe

# Make a DWARF split debug info file with gnu debuglink.
cp $TEST_DIR/hello-exception-dwarf.exe $TEST_DIR/hello-exception-split.exe
$OBJCOPY --only-keep-debug $TEST_DIR/hello-exception-split.exe $TEST_DIR/hello-exception-split.dbg
$OBJCOPY --strip-all $TEST_DIR/hello-exception-split.exe
objcopy.exe --add-gnu-debuglink=$TEST_DIR/hello-exception-split.dbg $TEST_DIR/hello-exception-split.exe

for i in libc++ libunwind; do
    if [ -f $PREFIX/$ARCH-w64-mingw32/bin/$i.dll ]; then
        cp $PREFIX/$ARCH-w64-mingw32/bin/$i.dll $TEST_DIR
    fi
done


# Test debugging a crashing executable, and check the backtrace of
# the crash.
OUT=lldb-test-out
SCRIPT=lldb-test-script
cat > $SCRIPT <<EOF
run
bt
EOF
for exe in hello-exception-dwarf.exe hello-exception-pdb.exe hello-exception-split.exe; do
    $LLDB -b -s $SCRIPT -- $TEST_DIR/$exe -crash < /dev/null > $OUT 2>/dev/null
    cat $OUT
    grep -q "Access violation" $OUT
    if [ "$ARCH" != "armv7" ] || [ "$exe" = "hello-exception-pdb.exe" ]; then
        grep -q "volatile int.*NULL.*0x42" $OUT
    fi
    if [ "$ARCH" != "armv7" ]; then
        # armv7 pdb gives "val=<unavailable>".
        grep -q "frame #0: .*hello-exception.*.exe.recurse(val=0) at hello-exception.cpp:" $OUT
        grep -q "hello-exception.*.exe.recurse(val=10) at hello-exception.cpp:" $OUT
    fi
done

exe=hello-exception-dwarf.exe
if [ "$ARCH" = "armv7" ]; then
    # LLDB works better on ARM with PDB than with DWARF.
    exe=hello-exception-pdb.exe
fi


# Test running into a programmatic breakpoint (__debugbreak), check the
# backtrace from there, and check that we can continue from it.
cat > $SCRIPT <<EOF
run
bt
cont
EOF
$LLDB -b -s $SCRIPT -- $TEST_DIR/$exe -breakpoint < /dev/null > $OUT 2>/dev/null
cat $OUT
grep -q "stop reason = Exception 0x80000003" $OUT
# Not checking that __debugbreak is "frame #0"; on arm/aarch64, the program
# counter points into the __debugbreak function, while on x86, it points to
# the calling recurse function.
grep -q "__debugbreak" $OUT
if [ "$ARCH" != "armv7" ]; then
    grep -q "hello-exception.*.exe.recurse(val=10) at hello-exception.cpp:" $OUT
fi
grep -q "exited with status = 0" $OUT


# Test setting a breakpoint in LLDB, checking the backtrace when we hit it,
# stepping from the breakpoint, and running to completion.
cat > $SCRIPT <<EOF
b done
run
bt
finish
cont
EOF
$LLDB -b -s $SCRIPT -- $TEST_DIR/$exe -noop < /dev/null > $OUT 2>/dev/null
cat $OUT
grep -q "Breakpoint 1: where = hello-exception.*.exe.done.* at hello-exception.cpp:" $OUT
grep -q "stop reason = breakpoint" $OUT
grep -q "frame #0: .*hello-exception.*.exe.done.* at hello-exception.cpp:" $OUT
if [ "$ARCH" != "armv7" ]; then
    grep -q "frame #0: .*hello-exception.*.exe.recurse(val=0) at hello-exception.cpp:" $OUT
    grep -q "hello-exception.*.exe.recurse(val=10) at hello-exception.cpp:" $OUT
fi
grep -q "exited with status = 0" $OUT

rm -f $OUT $SCRIPT
echo All tests succeeded
