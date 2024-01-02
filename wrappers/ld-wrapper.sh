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

BASENAME="$(basename "$0")"
TARGET="${BASENAME%-*}"
DEFAULT_TARGET=x86_64-linux-musl
if [ "$TARGET" = "$BASENAME" ]; then
    TARGET=$DEFAULT_TARGET
fi
ARCH="${TARGET%%-*}"
case $ARCH in
i*86)    M=elf_i386          ;;
x86_64)  M=elf_x86_64        ;;
arm*)    M=armelf_linux_eabi ;;
aarch64) M=aarch64linux      ;;
esac
FLAGS="-m $M"
ld.lld $FLAGS "$@"
