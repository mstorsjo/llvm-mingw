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

if [ ! -d mingw-w64 ]; then
    git clone git://git.code.sf.net/p/mingw-w64/mingw-w64
    CHECKOUT=1
fi

cd mingw-w64

if [ -n "$SYNC" ] || [ -n "$CHECKOUT" ]; then
    [ -z "$SYNC" ] || git fetch
    git checkout 1b29d1bc58910a4c21ff2c5c804bf06821032348
fi

cd mingw-w64-headers
mkdir -p build
cd build
../configure --prefix=$PREFIX/generic-w64-mingw32 \
    --enable-secure-api --enable-idl --with-default-win32-winnt=0x600 --with-default-msvcrt=ucrt INSTALL="install -C"
make install
cd ../..
for arch in $ARCHS; do
    mkdir -p $PREFIX/$arch-w64-mingw32
    ln -sfn ../generic-w64-mingw32/include $PREFIX/$arch-w64-mingw32/include
done

cd mingw-w64-crt
for arch in $ARCHS; do
    mkdir -p build-$arch
    cd build-$arch
    case $arch in
    armv7)
        FLAGS="--disable-lib32 --disable-lib64 --enable-libarm32"
        ;;
    aarch64)
        FLAGS="--disable-lib32 --disable-lib64 --enable-libarm64"
        ;;
    i686)
        FLAGS="--enable-lib32 --disable-lib64"
        ;;
    x86_64)
        FLAGS="--disable-lib32 --enable-lib64"
        ;;
    esac
    FLAGS="$FLAGS --with-default-msvcrt=ucrt"
    ../configure --host=$arch-w64-mingw32 --prefix=$PREFIX/$arch-w64-mingw32 $FLAGS \
        CC=$arch-w64-mingw32-clang AR=llvm-ar RANLIB=llvm-ranlib DLLTOOL=llvm-dlltool
    make -j$CORES
    make install
    cd ..
done
cd ..

cd ..
./build-mingw-w64-widl.sh "$PREFIX"
