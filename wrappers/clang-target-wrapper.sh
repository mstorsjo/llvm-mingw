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
    # Dwarf is the default for i686, but there are a few issues with
    # dwarf unwinding in code generated for i686, see
    # https://bugs.llvm.org/show_bug.cgi?id=40012 and
    # https://bugs.llvm.org/show_bug.cgi?id=40322.
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
