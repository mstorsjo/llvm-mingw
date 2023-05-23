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

get_dir() {
    target="$1"
    while [ -L "$target" ]; do
        cd "$(dirname "$target")"
        target="$(readlink "$(basename "$target")")"
    done
    cd "$(dirname "$target")"
    pwd
}

DIR="$(get_dir "$0")"
export PATH="$DIR":"$PATH"

if [ "$1" = "-f" ]; then
    # libtool can try to run objdump -f and wants to see certain strings in
    # the output, to accept it being a windows (import) library
    llvm-readobj $2 | while read -r line; do
        case $line in
        File:*)
            file=$(echo $line | awk '{print $2}')
            ;;
        Format:*)
            format=$(echo $line | awk '{print $2}')
            case $format in
            COFF-i386)
                format=pe-i386
                ;;
            COFF-x86-64)
                format=pe-x86-64
                ;;
            COFF-ARM*)
                # This is wrong; modern COFF armv7 isn't pe-arm-wince, and
                # arm64 definitely isn't, but libtool wants to see this
                # string (or some of the others) in order to accept it.
                format=pe-arm-wince
                ;;
            esac
            echo $file: file format $format
            ;;
        esac
    done
else
    llvm-objdump "$@"
fi
