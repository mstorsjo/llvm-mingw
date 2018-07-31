#!/bin/sh
DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="$(basename $0 | sed 's/-[^-]*$//')"
EXE=$(basename $0 | sed 's/.*-\([^-]*\)/\1/')
case $EXE in
clang++|g++)
    DRIVER_MODE=--driver-mode=g++
    ;;
esac
ARCH=$(echo $TARGET | sed 's/-.*//')
case $ARCH in
i686)
    # Dwarf is the default here.
    ARCH_FLAGS=
    ;;
x86_64)
    # Explicitly request dwarf on x86_64; SEH is the default there but
    # libcxxabi lacks support for it.
    ARCH_FLAGS=-fdwarf-exceptions
    ;;
armv7)
    # Dwarf is the default here.
    ARCH_FLAGS=
    ;;
aarch64)
    # Dwarf is the default here.
    ARCH_FLAGS=
    ;;
esac
# Allow setting e.g. CCACHE=1 to wrap all building in ccache.
if [ -n "$CCACHE" ]; then
    CCACHE=ccache
fi
$CCACHE $DIR/clang $DRIVER_MODE -target $TARGET -rtlib=compiler-rt -stdlib=libc++ -fuse-ld=lld -fuse-cxa-atexit $ARCH_FLAGS -Qunused-arguments "$@"
