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
TARGET_OS="${TARGET##*-}"

# The sysroot is automatically picked by the clang driver in itself, but
# we need it for target specific extra libs.
SYSROOT="$DIR/../$ARCH-w64-mingw32"

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
case $TARGET_OS in
mingw32uwp)
    # the UWP target is for Windows 10
    FLAGS="$FLAGS -D_WIN32_WINNT=0x0A00 -DWINVER=0x0A00"
    # the UWP target can only use Windows Store APIs
    FLAGS="$FLAGS -DWINAPI_FAMILY=WINAPI_FAMILY_APP"
    # the Windows Store API only supports Windows Unicode (some rare ANSI ones are available)
    FLAGS="$FLAGS -DUNICODE"
    # add the minimum runtime to use for UWP targets
    FLAGS="$FLAGS -Wl,-lmincore"
    # Force building code for UCRT, and use a libc++ built specifically
    # for UCRT, in case a different CRT was set as default.
    FLAGS="$FLAGS -D__MSVCRT_VERSION__=0x1400 -static-libstdc++ -L$SYSROOT/lib/ucrt -Wl,-lvcruntime140_app,-lucrt"
    ;;
esac

FLAGS="$FLAGS -target $TARGET"
FLAGS="$FLAGS -rtlib=compiler-rt"
FLAGS="$FLAGS -stdlib=libc++"
FLAGS="$FLAGS -fuse-ld=lld"
FLAGS="$FLAGS -fuse-cxa-atexit"
FLAGS="$FLAGS -Qunused-arguments"

$CCACHE $CLANG $FLAGS "$@"
