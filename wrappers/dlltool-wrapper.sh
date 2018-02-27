#!/bin/sh

TARGET="$(basename $0 | sed 's/-[^-]*$//')"
ARCH=$(echo $TARGET | sed 's/-.*//')
case $ARCH in
i686)    M=i386        ;;
x86_64)  M=i386:x86-64 ;;
armv7)   M=arm         ;;
aarch64) M=arm64       ;;
esac
llvm-dlltool -m $M "$@"
