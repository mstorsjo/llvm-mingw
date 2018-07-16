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

CLANG_VERSION=$(basename $(dirname $(dirname $(dirname $($PREFIX/bin/clang --print-libgcc-file-name -rtlib=compiler-rt)))))

if [ ! -d compiler-rt ]; then
    git clone -b master https://github.com/llvm-mirror/compiler-rt.git
    CHECKOUT=1
fi

# Add a symlink for i386 -> i686; we normally name the toolchain
# i686-w64-mingw32, but due to the compiler-rt cmake peculiarities, we
# need to refer to it as i386 at this stage.
ln -sfn i686-w64-mingw32 $PREFIX/i386-w64-mingw32 || true

cd compiler-rt

if [ -n "$SYNC" ] || [ -n "$CHECKOUT" ]; then
    [ -z "$SYNC" ] || git fetch
    git checkout 97adb78eaae40595d052cfa76514db8256063bea
fi

for arch in $ARCHS; do
    buildarchname=$arch
    libarchname=$arch
    case $arch in
    armv7)
        libarchname=arm
        ;;
    i686)
        buildarchname=i386
        libarchname=i386
        ;;
    esac
    mkdir -p build-$arch
    cd build-$arch
    cmake \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_C_COMPILER=$arch-w64-mingw32-clang \
        -DCMAKE_SYSTEM_NAME=Windows \
        -DCMAKE_AR=$PREFIX/bin/llvm-ar \
        -DCMAKE_RANLIB=$PREFIX/bin/llvm-ranlib \
        -DCMAKE_C_COMPILER_WORKS=1 \
        -DCMAKE_C_COMPILER_TARGET=$buildarchname-windows-gnu \
        -DCOMPILER_RT_DEFAULT_TARGET_ONLY=TRUE \
        ../lib/builtins
    make -j$CORES
    mkdir -p $PREFIX/lib/clang/$CLANG_VERSION/lib/windows
    cp lib/windows/libclang_rt.builtins-$buildarchname.a $PREFIX/lib/clang/$CLANG_VERSION/lib/windows/libclang_rt.builtins-$libarchname.a
    cd ..
done
