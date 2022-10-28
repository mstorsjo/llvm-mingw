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

CLANG_RESOURCE_DIR="$("$SRC/bin/clang" --print-resource-dir)"
CLANG_VERSION=$(basename "$CLANG_RESOURCE_DIR")

# If linked to a shared libc++/libunwind, we need to bundle those DLLs
# in the bin directory. For simplicity, copy all runtime DLLs to the
# bin directory - that way, users who have this directory in $PATH
# can run the executables they've built directly without fiddling
# with copying them.
cp $SRC/$CROSS_ARCH-w64-mingw32/bin/*.dll $DEST/bin

# Copy the clang resource files (include, lib, share). The clang cross
# build installs the main headers, but since we didn't build the runtimes
# (compiler-rt), we're lacking the files that are installed by them. The
# compiler-rt build primarily installs some libs, but also a few files under
# share, and headers for some of the runtime libraries.
#
# Instead of trying to merge these files on top of the headers installed
# by the clang cross build, just wipe the existing files and copy the whole
# resource directory from the complete toolchain. As long as it's a matching
# version of clang, the headers that were installed by it should be identical.
#
# Alternatively, we could copy the lib and share subdirectories, and
# copy the individual include subdirectories that are missing.
rm -rf $DEST/lib/clang/$CLANG_VERSION
cp -a $CLANG_RESOURCE_DIR $DEST/lib/clang/$CLANG_VERSION

rm -rf $DEST/include
# Copy over headers and arch specific files, converting a unix style
# install (everything in arch specific subdirectories) into
# what we'd have when built on Windows, as if build-mingw-w64.sh
# was called with --skip-include-triplet-prefit, with all headers
# in $DEST/include, and only keeping the bin and lib directories for the
# individual architectures.
cp -a $SRC/generic-w64-mingw32/include $DEST/include
for arch in $ARCHS; do
    mkdir -p $DEST/$arch-w64-mingw32
    for subdir in bin lib share; do
        cp -a $SRC/$arch-w64-mingw32/$subdir $DEST/$arch-w64-mingw32
    done
done
