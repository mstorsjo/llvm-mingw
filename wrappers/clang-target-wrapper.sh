#!/usr/bin/env bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$(basename $0 | sed 's/-[^-]*$//')"
EXE=$(basename $0 | sed 's/.*-\([^-]*\)/\1/')
case $EXE in
clang*)
    ;;
gcc)
    EXE=clang
    ;;
g++)
    EXE=clang++
    ;;
esac
ARCH=$(echo $TARGET | sed 's/-.*//')
case $ARCH in
i686)
    # Dwarf is the default for i686, but currently there's an issue
    # in libunwind with unwinding clang generated dwarf opcodes on 32 bit
    # x86, pending resolution at https://reviews.llvm.org/D38680.
    ARCH_FLAGS=-fsjlj-exceptions
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
$CCACHE $DIR/$EXE -target $TARGET -rtlib=compiler-rt -stdlib=libc++ -fuse-ld=lld $ARCH_FLAGS -Qunused-arguments "$@"
