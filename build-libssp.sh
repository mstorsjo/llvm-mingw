#!/bin/sh

set -e

if [ $# -lt 1 ]; then
    echo $0 dest
    exit 1
fi
PREFIX="$1"
export PATH=$PREFIX/bin:$PATH

: ${CORES:=4}
: ${ARCHS:=${TOOLCHAIN_ARCHS-i686 x86_64 armv7 aarch64}}

if [ ! -d libssp ]; then
    svn checkout -q svn://gcc.gnu.org/svn/gcc/tags/gcc_7_3_0_release/libssp
fi

cp libssp-Makefile libssp/Makefile

cd libssp

# gcc/libssp's configure script runs checks for flags that clang doesn't
# implement. We actually just need to set a few HAVE defines and compile
# the .c sources.
cp config.h.in config.h
for i in HAVE_FCNTL_H HAVE_INTTYPES_H HAVE_LIMITS_H HAVE_MALLOC_H \
    HAVE_MEMMOVE HAVE_MEMORY_H HAVE_MEMPCPY HAVE_STDINT_H HAVE_STDIO_H \
    HAVE_STDLIB_H HAVE_STRINGS_H HAVE_STRING_H HAVE_STRNCAT HAVE_STRNCPY \
    HAVE_SYS_STAT_H HAVE_SYS_TYPES_H HAVE_UNISTD_H HAVE_USABLE_VSNPRINTF; do
    cat config.h | sed 's/^#undef '$i'$/#define '$i' 1/' > tmp
    mv tmp config.h
done
cat ssp/ssp.h.in | sed 's/@ssp_have_usable_vsnprintf@/define/' > ssp/ssp.h

for arch in $ARCHS; do
    mkdir -p build-$arch
    cd build-$arch
    make -f ../Makefile -j$CORES CROSS=$arch-w64-mingw32-
    cp libssp.a $PREFIX/$arch-w64-mingw32/lib
    cp libssp.a $PREFIX/$arch-w64-mingw32/lib/libssp_nonshared.a
    cd ..
done
