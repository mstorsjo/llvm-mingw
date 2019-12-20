#!/bin/sh

set -e

unset HOST

: ${MAKE_VERSION:=4.2.1}

while [ $# -gt 0 ]; do
    case "$1" in
    --host=*)
        HOST="${1#*=}"
        ;;
    *)
        PREFIX="$1"
        ;;
    esac
    shift
done
if [ -z "$PREFIX" ]; then
    echo $0 [--host=<triple>] dest
    exit 1
fi

mkdir -p "$PREFIX"
PREFIX="$(cd "$PREFIX" && pwd)"

: ${CORES:=$(nproc 2>/dev/null)}
: ${CORES:=$(sysctl -n hw.ncpu 2>/dev/null)}
: ${CORES:=4}
: ${ARCHS:=${TOOLCHAIN_ARCHS-i686 x86_64 armv7 aarch64}}

download() {
    if [ -n "$(which wget)" ]; then
        wget "$1"
    else
        curl -LO "$1"
    fi
}

if [ ! -d make-$MAKE_VERSION ]; then
    download https://ftp.gnu.org/gnu/make/make-$MAKE_VERSION.tar.bz2
    tar -jxf make-$MAKE_VERSION.tar.bz2
fi

cd make-$MAKE_VERSION

if [ -n "$HOST" ]; then
    CONFIGFLAGS="$CONFIGFLAGS --host=$HOST"
    CROSS_NAME=-$HOST
fi

mkdir -p build$CROSS_NAME
cd build$CROSS_NAME
../configure --prefix="$PREFIX" $CONFIGFLAGS --program-prefix=mingw32- --enable-job-server LDFLAGS="-Wl,-s"
make -j$CORES
make install-binPROGRAMS
