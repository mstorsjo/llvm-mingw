#!/bin/sh

DIR="$(cd "$(dirname "$0")" && pwd)"
export PATH=$DIR:$PATH

if [ "$1" = "--help" ]; then
    cat<<EOF
GNU ld impersonation
We don't support --enable-auto-import, but libtool may look for this flag.
EOF
    exit 0
fi
if [ "$1" = "-v" ]; then
    # This isn't implemented in the lld mingw frontend, so don't
    # pass the -m <machine> option in this case.
    ld.lld -v
    exit 0
fi

TARGET="$(basename $0 | sed 's/-[^-]*$//')"
ARCH=$(echo $TARGET | sed 's/-.*//')
case $ARCH in
i686)    M=i386pe   ;;
x86_64)  M=i386pep  ;;
armv7)   M=thumb2pe ;;
aarch64) M=arm64pe  ;;
esac
ld.lld -m $M "$@"
