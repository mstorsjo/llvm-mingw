#!/bin/sh

DIR="$(cd "$(dirname "$0")" && pwd)"
export PATH=$DIR:$PATH

BASENAME="$(basename "$0")"
TARGET="${BASENAME%-*}"
ARCH="${TARGET%%-*}"
case $ARCH in
i686)    M=i386        ;;
x86_64)  M=i386:x86-64 ;;
armv7)   M=arm         ;;
aarch64) M=arm64       ;;
esac
llvm-dlltool -m $M "$@"
