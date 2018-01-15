#!/bin/sh

set -e

if [ $# -lt 1 ]; then
    echo $0 dest
    exit 1
fi
PREFIX="$1"

./build-llvm.sh $PREFIX
./install-wrappers.sh $PREFIX
./build-mingw-w64.sh $PREFIX
./build-compiler-rt.sh $PREFIX
./build-libcxx.sh $PREFIX
