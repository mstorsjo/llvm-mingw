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
    echo $0 native prefix arch
    exit 1
fi
NATIVE="$1"
PREFIX="$2"
CROSS_ARCH="$3"

export PATH=$NATIVE/bin:$PATH
HOST=$CROSS_ARCH-w64-mingw32

./build-llvm.sh $PREFIX --host=$HOST
./strip-llvm.sh $PREFIX --host=$HOST
./build-mingw-w64-tools.sh $PREFIX --skip-include-triplet-prefix --host=$HOST
./install-wrappers.sh $PREFIX --host=$HOST
./prepare-cross-toolchain.sh $NATIVE $PREFIX $CROSS_ARCH
./build-make.sh $PREFIX --host=$HOST
