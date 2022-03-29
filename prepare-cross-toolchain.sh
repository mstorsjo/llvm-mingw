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

if [ $# -lt 3 ]; then
    echo $0 src dest arch
    exit 1
fi
SRC="$1"
DEST="$2"
CROSS_ARCH="$3"

: ${ARCHS:=${TOOLCHAIN_ARCHS-i686 x86_64 armv7 aarch64}}

CLANG_VERSION=$(basename $(dirname $(dirname $(dirname $($SRC/bin/clang --print-libgcc-file-name -rtlib=compiler-rt)))))

# If linked to a shared libc++/libunwind, we need to bundle those DLLs
# in the bin directory.
for i in libc++ libunwind; do
    if [ -f $SRC/$CROSS_ARCH-w64-mingw32/bin/$i.dll ]; then
        cp $SRC/$CROSS_ARCH-w64-mingw32/bin/$i.dll $DEST/bin
    fi
done
