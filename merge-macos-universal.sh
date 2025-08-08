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

if [ $# -lt 2 ]; then
    echo $0 archive1.tar.xz archive2.tar.xz
    exit 1
fi

base1=${1%%.*}
base2=${2%%.*}

rm -rf "$base1" "$base2"
tar -Jxf $1
tar -Jxf $2

outbase="${base1%-*}-universal"

rm -rf "$outbase"
cp -a "$base1" "$outbase"

for i in $(cd "$base1"; find . -type f); do
#for i in $(cd "$base1"; echo bin/* lib/*.dylib); do
    if [ -L "$base1/$i" ] || [ ! -x "$base1/$i" ]; then
        continue
    fi
    if [ ! -x "$base2/$i" ]; then
        continue
    fi
    if file "$base1/$i" | sed 's/.*: *//' | grep -q Mach-O; then
        echo Merging $i
        lipo -create -output "$outbase/$i" "$base1/$i" "$base2/$i"
    fi
done

tar -Jcf $outbase.tar.xz $outbase
