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

set -e

if [ $# -lt 1 ]; then
    echo $0 dest
    exit 1
fi

MAKE=make
if [ "$(which gmake)" != "" ]; then
    MAKE=gmake
fi

PREFIX="$1"
mkdir -p "$PREFIX"
PREFIX="$(cd "$PREFIX" && pwd)"
export PATH="$PREFIX/bin:$PATH"

: ${CORES:=$(nproc 2>/dev/null)}
: ${CORES:=$(sysctl -n hw.ncpu 2>/dev/null)}
: ${CORES:=4}
: ${ARCHS:=${TOOLCHAIN_ARCHS-i686 x86_64 armv7 aarch64}}

if [ ! -d libssp ]; then
    svn checkout -q svn://gcc.gnu.org/svn/gcc/tags/gcc_9_2_0_release/libssp
    for i in patches/libssp/*.patch; do
        patch -p1 < $i
    done
    (cd libssp; autoreconf -fiv)
fi

cd libssp

for arch in $ARCHS; do
    [ -z "$CLEAN" ] || rm -rf build-$arch
    mkdir -p build-$arch
    cd build-$arch
    ../configure --prefix="$PREFIX/$arch-w64-mingw32" --host=$arch-w64-mingw32
    $MAKE -j$CORES install
    cd ..
done
