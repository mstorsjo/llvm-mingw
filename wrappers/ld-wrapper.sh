#!/bin/sh

DIR="$(cd "$(dirname "$0")" && pwd)"
export PATH="$DIR":"$PATH"

BASENAME="$(basename "$0")"
TARGET="${BASENAME%-*}"
DEFAULT_TARGET=x86_64-w64-mingw32
if [ "$TARGET" = "$BASENAME" ]; then
    TARGET=$DEFAULT_TARGET
fi
ARCH="${TARGET%%-*}"
TARGET_OS="${TARGET##*-}"
case $ARCH in
i686)    M=i386pe   ;;
x86_64)  M=i386pep  ;;
armv7)   M=thumb2pe ;;
aarch64) M=arm64pe  ;;
esac
FLAGS="-m $M"
case $TARGET_OS in
mingw32uwp)
    FLAGS="$FLAGS -lmincore -lvcruntime140_app"
    ;;
esac
ld.lld $FLAGS "$@"
