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
SYSROOT="$(cd "$DIR"/../$TARGET && pwd)"
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
	# Dwarf is the default on aarch64; enable emulated TLS since native
	# TLS isn't implemented yet.
	ARCH_FLAGS=-femulated-tls
	;;
esac
$DIR/$EXE -target $TARGET -rtlib=compiler-rt -stdlib=libc++ -fuse-ld=lld --sysroot="$SYSROOT" $ARCH_FLAGS -Qunused-arguments "$@"
