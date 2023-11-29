#!/bin/sh
#
# Copyright (c) 2023 Martin Storsjo
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

while [ $# -gt 0 ]; do
    if [ -z "$PREFIX" ]; then
        PREFIX="$1"
    elif [ -z "$MSYS_ENV" ]; then
        MSYS_ENV="$1"
    else
        echo Unrecognized parameter $1
        exit 1
    fi
    shift
done
if [ -z "$MSYS_ENV" ]; then
    echo $0 prefix msys_env
    exit 1
fi

cd $PREFIX/bin
for i in ld.lld.exe clang-*.exe lldb.exe; do
    if [ ! -f "$i" ]; then
        continue
    fi
    for f in $(ldd "$i" | grep /$MSYS_ENV | awk '{print $3}'); do
        if [ ! -f "$(basename $f)" ]; then
            echo Copying $f
            cp $f .
        fi
    done
done
