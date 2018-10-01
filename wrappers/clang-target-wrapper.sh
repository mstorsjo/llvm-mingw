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
    # to unwind correctly on i686. This issue might be related to cases
    # of DW_CFA_GNU_args_size (which were adjusted in libunwind SVN r337312).
    # The issue can be reproduced with test/exception-locale.cpp.
    # The issue goes away if building libunwind/libcxxabi/libcxx and the
    # test example with -mstack-alignment=16 -mstackrealign.
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
