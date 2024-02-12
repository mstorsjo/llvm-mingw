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
    echo $0 tag
    exit 1
fi

TAG=$1

# macOS itself doesn't ship with libzstd; avoid picking up a zstd
# dependency from libraries installed e.g. with homebrew.
export LLVM_CMAKEFLAGS="-DLLVM_ENABLE_ZSTD=OFF"

RELNAME=llvm-mingw-$TAG-ucrt-macos-universal
DEST=$HOME/$RELNAME
rm -rf $DEST
time CLEAN=1 SYNC=1 MACOS_REDIST=1 ./build-all.sh $DEST
dir=$(pwd)
cd $HOME
TAR=tar
if command -v gtar >/dev/null; then
    TAR_FLAGS="--numeric-owner --owner=0 --group=0"
    TAR=gtar
fi
$TAR -Jcvf $dir/$RELNAME.tar.xz --format=ustar $TAR_FLAGS $RELNAME
rm -rf $RELNAME
cd $dir
ls -lh $RELNAME.tar.xz
