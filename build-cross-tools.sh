#!/bin/sh

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
./build-mingw-w64.sh $PREFIX --skip-include-triplet-prefix --host=$HOST
./install-wrappers.sh $PREFIX --host=$HOST
./prepare-cross-toolchain.sh $NATIVE $PREFIX $CROSS_ARCH
