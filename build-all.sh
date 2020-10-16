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
PREFIX="$1"

for dep in git svn cmake; do
    if ! hash $dep 2>/dev/null; then
        echo "$dep not installed. Please install it and retry" 1>&2
        exit 1
    fi
done

./build-llvm.sh $PREFIX
./install-wrappers.sh $PREFIX
./build-mingw-w64.sh $PREFIX
./build-mingw-w64-tools.sh $PREFIX
./build-compiler-rt.sh $PREFIX
./build-mingw-w64-libraries.sh $PREFIX
./build-libcxx.sh $PREFIX
./build-compiler-rt.sh $PREFIX --build-sanitizers
./build-libssp.sh $PREFIX
