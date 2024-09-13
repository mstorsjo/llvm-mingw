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
BASENAME="$(basename "$0")"
TARGET="${BASENAME%-*}"
EXE="${BASENAME##*-}"
DEFAULT_TARGET=x86_64-linux-musl
if [ "$TARGET" = "$BASENAME" ]; then
    TARGET=$DEFAULT_TARGET
fi
SYSROOT="$(dirname "$DIR")/generic-linux-musl"

# Check if trying to compile Ada; if we try to do this, invoking clang
# would end up invoking <triplet>-gcc with the same arguments, which ends
# up in an infinite recursion.
case "$*" in
*-x\ ada*)
    echo "Ada is not supported" >&2
    exit 1
    ;;
*)
    ;;
esac

# Allow setting e.g. CCACHE=1 to wrap all building in ccache.
if [ -n "$CCACHE" ]; then
    CCACHE=ccache
fi

# If changing this wrapper, change clang-target-wrapper.c accordingly.
CLANG="$DIR/clang"
FLAGS=""
FLAGS="$FLAGS --start-no-unused-arguments"
case $EXE in
clang++|g++|c++)
    FLAGS="$FLAGS --driver-mode=g++"
    ;;
c99)
    FLAGS="$FLAGS -std=c99"
    ;;
c11)
    FLAGS="$FLAGS -std=c11"
    ;;
esac

FLAGS="$FLAGS -target $TARGET"
FLAGS="$FLAGS --end-no-unused-arguments"

$CCACHE "$CLANG" $FLAGS "$@" $LINKER_FLAGS
