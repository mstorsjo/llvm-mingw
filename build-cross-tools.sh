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
export EXEEXT=.exe
export HOST=$CROSS_ARCH-w64-mingw32

./build-llvm.sh $PREFIX
./strip-llvm.sh $PREFIX
./build-mingw-w64-widl.sh $PREFIX --skip-triplet-prefix
./install-wrappers.sh $PREFIX
./prepare-cross-toolchain.sh $NATIVE $PREFIX $CROSS_ARCH
