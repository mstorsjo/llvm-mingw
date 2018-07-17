#!/bin/sh

set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="$(basename $0 | sed 's/-[^-]*$//')"
EXE=$(basename $0 | sed 's/.*-\([^-]*\)/\1/')
ARCH=$(echo $TARGET | sed 's/-.*//')

IN=""
OUT=""
ARGS=""
STRIP=""
while [ $# -gt 0 ]; do
    case $1 in
    --strip*|-g|-S)
        STRIP=1
        ;;
    -*)
        ;;
    *)
        if [ -z "$IN" ]; then
            IN="$1"
        elif [ -z "$OUT" ]; then
            OUT="$1"
        else
            echo Unhandled arg $1
            exit 1
        fi
        ;;
    esac
    ARGS="$ARGS $1"
    shift
done
if [ -n "$IN" ] && [ -z "$OUT" ]; then
	OUT="$IN"
fi

case $ARCH in
i686|x86_64) COMPAT_ARCH=$ARCH;;
armv7)       COMPAT_ARCH=i686;;
aarch64)     COMPAT_ARCH=x86_64;;
esac

convert() {
    if [ "$ARCH" = "$COMPAT_ARCH" ]; then
        return
    fi
    $DIR/change-pe-arch "$@"
}

checkstrip() {
    if [ "$EXE" = "strip" ]; then
        return 0
    elif [ -n "$STRIP" ]; then
        if [ "$IN" != "$OUT" ]; then
            cp "$IN" "$OUT"
        fi
        return 0
    else
        return 1
    fi
}

if [ "$ARCH" != "$COMPAT_ARCH" ] && ! $DIR/change-pe-arch -check "$IN"; then
    if checkstrip; then
        echo Ignoring strip of non-executable \(object file\?\) >&2
        exit 0
    else
        echo Unsupported "$0 $ARGS", not supported for non-executable \(object file\?\) >&2
        exit 1
    fi
fi

if [ -x $DIR/binutils-$EXE ]; then
    convert -from $ARCH -to $COMPAT_ARCH "$IN"
    $DIR/binutils-$EXE $ARGS
    convert -from $COMPAT_ARCH -to $ARCH "$OUT"
    if [ "$OUT" != "$IN" ]; then
        convert -from $COMPAT_ARCH -to $ARCH "$IN"
    fi
else
    if checkstrip; then
        echo Ignoring strip, missing binutils-$EXE >&2
        exit 0
    else
        echo Unsupported "$0 $ARGS", missing binutils-$EXE >&2
        exit 1
    fi
fi
