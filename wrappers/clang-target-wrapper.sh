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
    # Dwarf is the default for i686, but libunwind sometimes fails to
    # to unwind correctly on i686. The issue can be reproduced with
    # test/exception-locale.cpp. The issue might be related to
    # DW_CFA_GNU_args_size, since it goes away if building
    # libunwind/libcxxabi/libcxx and the test example with
    # -mstack-alignment=16 -mstackrealign. (libunwind SVN r337312 fixed
    # some handling relating to this dwarf opcode, which made
    # test/hello-exception.cpp work properly, but apparently there are
    # still issues with it).
    ARCH_FLAGS=-fsjlj-exceptions
    ;;
x86_64)
    # SEH is the default here.
    ARCH_FLAGS=
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
