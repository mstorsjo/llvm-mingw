#!/bin/sh

set -e

BUILD_STATIC=1
BUILD_SHARED=1

while [ $# -gt 0 ]; do
    if [ "$1" = "--disable-shared" ]; then
        BUILD_SHARED=
    elif [ "$1" = "--enable-shared" ]; then
        BUILD_SHARED=1
    elif [ "$1" = "--disable-static" ]; then
        BUILD_STATIC=
    elif [ "$1" = "--enable-static" ]; then
        BUILD_STATIC=1
    else
        PREFIX="$1"
    fi
    shift
done
if [ -z "$PREFIX" ]; then
    echo $0 [--disable-shared] [--disable-static] dest
    exit 1
fi
export PATH=$PREFIX/bin:$PATH

: ${CORES:=$(nproc 2>/dev/null)}
: ${CORES:=$(sysctl -n hw.ncpu 2>/dev/null)}
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
    git checkout 5f7425947f303be5ca9b1a6471471d92d209f498
    cd ..
fi
if [ -n "$SYNC" ] || [ -n "$CHECKOUT_LIBCXX" ]; then
    cd libcxx
    [ -z "$SYNC" ] || git fetch
    git checkout 8220dac54c22c42a5ec2a32a0ed50343a2ea4775
    cd ..
fi

LIBCXX=$(pwd)/libcxx
MERGE_ARCHIVES=$(pwd)/merge-archives.sh

build_all() {
    type="$1"
    if [ "$type" = "shared" ]; then
        SHARED=TRUE
        STATIC=FALSE
    else
        SHARED=FALSE
        STATIC=TRUE
    fi

    cd libunwind
    for arch in $ARCHS; do
        mkdir -p build-$arch-$type
        cd build-$arch-$type
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
            -DLIBUNWIND_ENABLE_SHARED=$SHARED \
            -DLIBUNWIND_ENABLE_STATIC=$STATIC \
            -DLIBUNWIND_ENABLE_CROSS_UNWINDING=FALSE \
            -DLIBUNWIND_STANDALONE_BUILD=TRUE \
            -DCMAKE_CXX_FLAGS="-nostdinc++ -I$LIBCXX/include -w" \
            -DCMAKE_C_FLAGS="-w" \
            -DCMAKE_SHARED_LINKER_FLAGS="-lpsapi" \
            ..
        make -j$CORES
        make install
        if [ "$type" = "shared" ]; then
            cp lib/libunwind.dll $PREFIX/$arch-w64-mingw32/bin
        else
            # Merge libpsapi.a into the static library libunwind.a, to
            # avoid having to specify -lpsapi when linking to it.
            $MERGE_ARCHIVES \
                $PREFIX/$arch-w64-mingw32/lib/libunwind.a \
                $PREFIX/$arch-w64-mingw32/lib/libpsapi.a
        fi
        cd ..
    done
    cd ..

    cd libcxxabi
    for arch in $ARCHS; do
        mkdir -p build-$arch-$type
        cd build-$arch-$type
        # If llvm-config and the llvm cmake files are available, -w gets added
        # to the compiler flags; manually add it here to avoid noisy warnings
        # that normally are suppressed.
        if [ "$type" = "shared" ]; then
            LIBCXXABI_VISIBILITY_FLAGS="-D_LIBCPP_BUILDING_LIBRARY -U_LIBCXXABI_DISABLE_VISIBILITY_ANNOTATIONS"
        else
            LIBCXXABI_VISIBILITY_FLAGS="-D_LIBCPP_DISABLE_VISIBILITY_ANNOTATIONS"
        fi
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
            -DLIBCXXABI_LIBDIR_SUFFIX="" \
            -DLIBCXXABI_ENABLE_NEW_DELETE_DEFINITIONS=OFF \
            -DLLVM_NO_OLD_LIBSTDCXX=TRUE \
            -DCXX_SUPPORTS_CXX11=TRUE \
            -DCMAKE_CXX_FLAGS="$LIBCXXABI_VISIBILITY_FLAGS -D_LIBCPP_HAS_THREAD_API_WIN32 -w" \
            ..
        make -j$CORES
        cd ..
    done
    cd ..

    cd libcxx
    for arch in $ARCHS; do
        mkdir -p build-$arch-$type
        cd build-$arch-$type
        if [ "$type" = "shared" ]; then
            LIBCXX_VISIBILITY_FLAGS="-D_LIBCXXABI_BUILDING_LIBRARY"
        else
            LIBCXX_VISIBILITY_FLAGS="-D_LIBCXXABI_DISABLE_VISIBILITY_ANNOTATIONS"
        fi
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
            -DLIBCXX_ENABLE_SHARED=$SHARED \
            -DLIBCXX_ENABLE_STATIC=$STATIC \
            -DLIBCXX_SUPPORTS_STD_EQ_CXX11_FLAG=TRUE \
            -DLIBCXX_HAVE_CXX_ATOMICS_WITHOUT_LIB=TRUE \
            -DLIBCXX_ENABLE_EXPERIMENTAL_LIBRARY=OFF \
            -DLIBCXX_ENABLE_FILESYSTEM=OFF \
            -DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=TRUE \
            -DLIBCXX_ABI_UNSTABLE=TRUE \
            -DLIBCXX_CXX_ABI=libcxxabi \
            -DLIBCXX_CXX_ABI_INCLUDE_PATHS=../../libcxxabi/include \
            -DLIBCXX_CXX_ABI_LIBRARY_PATH=../../libcxxabi/build-$arch-$type/lib \
            -DLIBCXX_LIBDIR_SUFFIX="" \
            -DCMAKE_CXX_FLAGS="$LIBCXX_VISIBILITY_FLAGS" \
            -DCMAKE_SHARED_LINKER_FLAGS="-lunwind -Wl,--export-all-symbols" \
            -DLIBCXX_ENABLE_ABI_LINKER_SCRIPT=FALSE \
            ..
        make -j$CORES
        make install
        if [ "$type" = "shared" ]; then
            $MERGE_ARCHIVES \
                $PREFIX/$arch-w64-mingw32/lib/libc++.dll.a \
                $PREFIX/$arch-w64-mingw32/lib/libunwind.dll.a
            cp lib/libc++.dll $PREFIX/$arch-w64-mingw32/bin
        else
            $MERGE_ARCHIVES \
                $PREFIX/$arch-w64-mingw32/lib/libc++.a \
                $PREFIX/$arch-w64-mingw32/lib/libunwind.a
        fi
        cd ..
    done
    cd ..
}

# Build shared first and static afterwards; the headers for static linking also
# work when linking against the DLL, but not vice versa.
[ -z "$BUILD_SHARED" ] || build_all shared
[ -z "$BUILD_STATIC" ] || build_all static
