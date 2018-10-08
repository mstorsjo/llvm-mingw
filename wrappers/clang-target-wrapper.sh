#!/bin/sh
DIR="$(cd "$(dirname "$0")" && pwd)"
BASENAME="$(basename "$0")"
TARGET="${BASENAME%-*}"
EXE="${BASENAME##*-}"
DEFAULT_TARGET=x86_64-w64-mingw32
if [ "$TARGET" = "$BASENAME" ]; then
    TARGET=$DEFAULT_TARGET
fi
ARCH="${TARGET%%-*}"

# Check if trying to compile Ada; if we try to do this, invoking clang
# would end up invoking <triplet>-gcc with the same arguments, which ends
# up in an infinite recursion.
case "$*" in
*-x\ ada*)
    echo "Ada is not supported" >&2
    exit 1
    ;;
*)
    ;;
esac

# Allow setting e.g. CCACHE=1 to wrap all building in ccache.
if [ -n "$CCACHE" ]; then
    CCACHE=ccache
fi

# If changing this wrapper, change clang-target-wrapper.c accordingly.
CLANG="$DIR/clang"
FLAGS=""
case $EXE in
clang++|g++|c++)
    FLAGS="$FLAGS --driver-mode=g++"
    ;;
esac
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
    FLAGS="$FLAGS -fsjlj-exceptions"
    ;;
x86_64)
    # SEH is the default here.
    ;;
armv7)
    # Dwarf is the default here.
    ;;
aarch64)
    # Dwarf is the default here.
    ;;
esac

FLAGS="$FLAGS -target $TARGET"
FLAGS="$FLAGS -rtlib=compiler-rt"
FLAGS="$FLAGS -stdlib=libc++"
FLAGS="$FLAGS -fuse-ld=lld"
FLAGS="$FLAGS -fuse-cxa-atexit"
FLAGS="$FLAGS -Qunused-arguments"

$CCACHE $CLANG $FLAGS "$@"
