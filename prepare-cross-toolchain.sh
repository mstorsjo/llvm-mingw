#!/bin/sh

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

cp -a $SRC/lib/clang/$CLANG_VERSION/lib $DEST/lib/clang/$CLANG_VERSION
rm -rf $DEST/include
cp -a $SRC/generic-w64-mingw32/include $DEST/include
for arch in $ARCHS; do
    mkdir -p $DEST/$arch-w64-mingw32
    for subdir in bin lib; do
        cp -a $SRC/$arch-w64-mingw32/$subdir $DEST/$arch-w64-mingw32
    done
done
