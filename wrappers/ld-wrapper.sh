#!/bin/sh

DIR="$(cd "$(dirname "$0")" && pwd)"
export PATH="$DIR":"$PATH"

if [ "$1" = "--help" ]; then
    cat<<EOF
GNU ld impersonation
We don't support the --enable-auto-import flag (it's enabled by default just
like it is in GNU ld), but we do support the feature itself. Libtool may
look for this flag.
EOF
    exit 0
fi
if [ "$1" = "-v" ]; then
    # This isn't implemented in the lld mingw frontend, so don't
    # pass the -m <machine> option in this case.
    ld.lld -v
    exit 0
fi

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
