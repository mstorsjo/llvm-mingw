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

if [ ! -d libunwind ]; then
    git clone -b master https://github.com/llvm-mirror/libunwind.git
    CHECKOUT_LIBUNWIND=1
fi
if [ ! -d libcxxabi ]; then
    git clone -b master https://github.com/llvm-mirror/libcxxabi.git
    CHECKOUT_LIBCXXABI=1
fi
if [ ! -d libcxx ]; then
    git clone -b master https://github.com/llvm-mirror/libcxx.git
    CHECKOUT_LIBCXX=1
fi
if [ -n "$SYNC" ] || [ -n "$CHECKOUT_LIBUNWIND" ]; then
    cd libunwind
    [ -z "$SYNC" ] || git fetch
    git checkout 1f89d78bb488bc71cfdee8281fc0834e9fbe5dce
    cd ..
fi
if [ -n "$SYNC" ] || [ -n "$CHECKOUT_LIBCXXABI" ]; then
    cd libcxxabi
    [ -z "$SYNC" ] || git fetch
    git checkout 1839f48cee24173f2cc06120778b2920dd2b257a
    cd ..
fi
if [ -n "$SYNC" ] || [ -n "$CHECKOUT_LIBCXX" ]; then
    cd libcxx
    [ -z "$SYNC" ] || git fetch
    git checkout e25adff05a0c53f92f0ca353a97f14ac90111a88
    cd ..
fi

LIBCXX=$(pwd)/libcxx
MERGE_ARCHIVES=$(pwd)/merge-archives.sh

case $(uname) in
MINGW*)
    echo "set(CMAKE_GENERATOR \"MSYS Makefiles\" CACHE INTERNAL \"\" FORCE)" > PreLoad.cmake
    ;;
*)
    ;;
esac

cd libunwind
for arch in $ARCHS; do
    mkdir -p build-$arch
    cd build-$arch
    if [ -f ../../PreLoad.cmake ]; then cp ../../PreLoad.cmake .; fi
    # If llvm-config and the llvm cmake files are available, -w gets added
    # to the compiler flags; manually add it here to avoid noisy warnings
    # that normally are suppressed.
    cmake \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=$PREFIX/$arch-w64-mingw32 \
        -DCMAKE_C_COMPILER=$arch-w64-mingw32-clang \
        -DCMAKE_CXX_COMPILER=$arch-w64-mingw32-clang++ \
        -DCMAKE_CROSSCOMPILING=TRUE \
        -DCMAKE_SYSTEM_NAME=Windows \
        -DCMAKE_C_COMPILER_WORKS=TRUE \
        -DCMAKE_CXX_COMPILER_WORKS=TRUE \
        -DCMAKE_AR=$PREFIX/bin/llvm-ar \
        -DCMAKE_RANLIB=$PREFIX/bin/llvm-ranlib \
        -DLLVM_NO_OLD_LIBSTDCXX=TRUE \
        -DCXX_SUPPORTS_CXX11=TRUE \
        -DLIBUNWIND_USE_COMPILER_RT=TRUE \
        -DLIBUNWIND_ENABLE_THREADS=TRUE \
        -DLIBUNWIND_ENABLE_SHARED=FALSE \
        -DLIBUNWIND_ENABLE_CROSS_UNWINDING=FALSE \
        -DLIBUNWIND_STANDALONE_BUILD=TRUE \
        -DCMAKE_CXX_FLAGS="-nostdinc++ -I$LIBCXX/include -w" \
        -DCMAKE_C_FLAGS="-w" \
        ..
    make -j$CORES
    make install
    # Merge libpsapi.a into the static library libunwind.a, to
    # avoid having to specify -lpsapi when linking to it.
    $MERGE_ARCHIVES \
        $PREFIX/$arch-w64-mingw32/lib/libunwind.a \
        $PREFIX/$arch-w64-mingw32/lib/libpsapi.a
    cd ..
done
cd ..

cd libcxxabi
for arch in $ARCHS; do
    mkdir -p build-$arch
    cd build-$arch
    if [ -f ../../PreLoad.cmake ]; then cp ../../PreLoad.cmake .; fi
    # If llvm-config and the llvm cmake files are available, -w gets added
    # to the compiler flags; manually add it here to avoid noisy warnings
    # that normally are suppressed.
    cmake \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=$PREFIX/$arch-w64-mingw32 \
        -DCMAKE_C_COMPILER=$arch-w64-mingw32-clang \
        -DCMAKE_CXX_COMPILER=$arch-w64-mingw32-clang++ \
        -DCMAKE_CROSSCOMPILING=TRUE \
        -DCMAKE_SYSTEM_NAME=Windows \
        -DCMAKE_C_COMPILER_WORKS=TRUE \
        -DCMAKE_CXX_COMPILER_WORKS=TRUE \
        -DCMAKE_AR=$PREFIX/bin/llvm-ar \
        -DCMAKE_RANLIB=$PREFIX/bin/llvm-ranlib \
        -DLIBCXXABI_USE_COMPILER_RT=ON \
        -DLIBCXXABI_ENABLE_EXCEPTIONS=ON \
        -DLIBCXXABI_ENABLE_THREADS=ON \
        -DLIBCXXABI_TARGET_TRIPLE=$arch-w64-mingw32 \
        -DLIBCXXABI_ENABLE_SHARED=OFF \
        -DLIBCXXABI_LIBCXX_INCLUDES=../../libcxx/include \
        -DLLVM_NO_OLD_LIBSTDCXX=TRUE \
        -DCXX_SUPPORTS_CXX11=TRUE \
        -DCMAKE_CXX_FLAGS="-D_LIBCPP_DISABLE_VISIBILITY_ANNOTATIONS -D_LIBCPP_HAS_THREAD_API_WIN32 -w" \
        ..
    make -j$CORES
    cd ..
done
cd ..

cd libcxx
for arch in $ARCHS; do
    mkdir -p build-$arch
    cd build-$arch
    if [ -f ../../PreLoad.cmake ]; then cp ../../PreLoad.cmake .; fi
    cmake \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=$PREFIX/$arch-w64-mingw32 \
        -DCMAKE_C_COMPILER=$arch-w64-mingw32-clang \
        -DCMAKE_CXX_COMPILER=$arch-w64-mingw32-clang++ \
        -DCMAKE_CROSSCOMPILING=TRUE \
        -DCMAKE_SYSTEM_NAME=Windows \
        -DCMAKE_C_COMPILER_WORKS=TRUE \
        -DCMAKE_CXX_COMPILER_WORKS=TRUE \
        -DCMAKE_AR=$PREFIX/bin/llvm-ar \
        -DCMAKE_RANLIB=$PREFIX/bin/llvm-ranlib \
        -DLIBCXX_USE_COMPILER_RT=ON \
        -DLIBCXX_INSTALL_HEADERS=ON \
        -DLIBCXX_ENABLE_EXCEPTIONS=ON \
        -DLIBCXX_ENABLE_THREADS=ON \
        -DLIBCXX_HAS_WIN32_THREAD_API=ON \
        -DLIBCXX_ENABLE_MONOTONIC_CLOCK=ON \
        -DLIBCXX_ENABLE_SHARED=OFF \
        -DLIBCXX_SUPPORTS_STD_EQ_CXX11_FLAG=TRUE \
        -DLIBCXX_HAVE_CXX_ATOMICS_WITHOUT_LIB=TRUE \
        -DLIBCXX_ENABLE_EXPERIMENTAL_LIBRARY=OFF \
        -DLIBCXX_ENABLE_FILESYSTEM=OFF \
        -DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=TRUE \
        -DLIBCXX_CXX_ABI=libcxxabi \
        -DLIBCXX_CXX_ABI_INCLUDE_PATHS=../../libcxxabi/include \
        -DLIBCXX_CXX_ABI_LIBRARY_PATH=../../libcxxabi/build-$arch/lib \
        -DCMAKE_CXX_FLAGS="-D_LIBCXXABI_DISABLE_VISIBILITY_ANNOTATIONS" \
        ..
    make -j$CORES
    make install
    $MERGE_ARCHIVES \
        $PREFIX/$arch-w64-mingw32/lib/libc++.a \
        $PREFIX/$arch-w64-mingw32/lib/libunwind.a
    cd ..
done
cd ..
rm -f PreLoad.cmake
