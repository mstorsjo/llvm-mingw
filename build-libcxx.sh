#!/bin/sh

set -e

BUILD_STATIC=1
BUILD_SHARED=1
BUILD_OTHER_CRT=1

while [ $# -gt 0 ]; do
    if [ "$1" = "--disable-shared" ]; then
        BUILD_SHARED=
    elif [ "$1" = "--enable-shared" ]; then
        BUILD_SHARED=1
    elif [ "$1" = "--disable-static" ]; then
        BUILD_STATIC=
    elif [ "$1" = "--enable-static" ]; then
        BUILD_STATIC=1
    elif [ "$1" = "--disable-other-crt" ]; then
        BUILD_OTHER_CRT=
    else
        PREFIX="$1"
    fi
    shift
done
if [ -z "$PREFIX" ]; then
    echo $0 [--disable-shared] [--disable-static] [--disable-other-crt] dest
    exit 1
fi

mkdir -p "$PREFIX"
PREFIX="$(cd "$PREFIX" && pwd)"

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
    git checkout df9c0cfd896524ae16dd7283cdf722f300c2b45d
    cd ..
fi
if [ -n "$SYNC" ] || [ -n "$CHECKOUT_LIBCXXABI" ]; then
    cd libcxxabi
    [ -z "$SYNC" ] || git fetch
    git checkout cac80b29da529d44ceb63930679e3a1af9cace37
    cd ..
fi
if [ -n "$SYNC" ] || [ -n "$CHECKOUT_LIBCXX" ]; then
    cd libcxx
    [ -z "$SYNC" ] || git fetch
    git checkout 632573ce43e1a8362c4c15a6ad645fe0155ab29f
    cd ..
fi

LIBCXX=$(pwd)/libcxx

case $(uname) in
MINGW*)
    CMAKE_GENERATOR="MSYS Makefiles"
    ;;
*)
    ;;
esac

build_all() {
    type="$1"
    variant="$2"
    extra_cflags="$3"
    extra_ldflags="$4"
    if [ "$type" = "shared" ]; then
        SHARED=TRUE
        STATIC=FALSE
    else
        SHARED=FALSE
        STATIC=TRUE
    fi

    cd libunwind
    for arch in $ARCHS; do
        builddir="build-$arch-$type"
        subdir=""
        if [ -n "$variant" ]; then
            builddir="$builddir-$variant"
            subdir="/$variant"
        fi

        mkdir -p $builddir
        cd $builddir
        cmake \
            ${CMAKE_GENERATOR+-G} "$CMAKE_GENERATOR" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=$PREFIX/$arch-w64-mingw32 \
            -DCMAKE_C_COMPILER=$arch-w64-mingw32-clang \
            -DCMAKE_CXX_COMPILER=$arch-w64-mingw32-clang++ \
            -DCMAKE_CROSSCOMPILING=TRUE \
            -DCMAKE_SYSTEM_NAME=Windows \
            -DCMAKE_C_COMPILER_WORKS=TRUE \
            -DCMAKE_CXX_COMPILER_WORKS=TRUE \
            -DLLVM_COMPILER_CHECKED=TRUE \
            -DCMAKE_AR=$PREFIX/bin/llvm-ar \
            -DCMAKE_RANLIB=$PREFIX/bin/llvm-ranlib \
            -DLLVM_NO_OLD_LIBSTDCXX=TRUE \
            -DCXX_SUPPORTS_CXX11=TRUE \
            -DCXX_SUPPORTS_CXX_STD=TRUE \
            -DLIBUNWIND_USE_COMPILER_RT=TRUE \
            -DLIBUNWIND_ENABLE_THREADS=TRUE \
            -DLIBUNWIND_ENABLE_SHARED=$SHARED \
            -DLIBUNWIND_ENABLE_STATIC=$STATIC \
            -DLIBUNWIND_ENABLE_CROSS_UNWINDING=FALSE \
            -DLIBUNWIND_STANDALONE_BUILD=TRUE \
            -DLIBUNWIND_LIBDIR_SUFFIX="$subdir" \
            -DCMAKE_CXX_FLAGS="-Wno-dll-attribute-on-redeclaration $extra_flags" \
            -DCMAKE_C_FLAGS="-Wno-dll-attribute-on-redeclaration $extra_cflags" \
            -DCMAKE_SHARED_LINKER_FLAGS="-lpsapi $extra_ldflags" \
            ..
        make -j$CORES
        make install
        if [ "$type" = "shared" ]; then
            mkdir -p $PREFIX/$arch-w64-mingw32/bin
            cp lib/libunwind.dll $PREFIX/$arch-w64-mingw32/bin
        else
            # Merge libpsapi.a into the static library libunwind.a, to
            # avoid having to specify -lpsapi when linking to it.
            llvm-ar qcsL \
                $PREFIX/$arch-w64-mingw32/lib$subdir/libunwind.a \
                $PREFIX/$arch-w64-mingw32/lib/libpsapi.a
        fi
        cd ..
    done
    cd ..

    cd libcxxabi
    for arch in $ARCHS; do
        mkdir -p $builddir
        cd $builddir
        if [ "$type" = "shared" ]; then
            LIBCXXABI_VISIBILITY_FLAGS="-D_LIBCPP_BUILDING_LIBRARY= -U_LIBCXXABI_DISABLE_VISIBILITY_ANNOTATIONS"
        else
            LIBCXXABI_VISIBILITY_FLAGS="-D_LIBCPP_DISABLE_VISIBILITY_ANNOTATIONS"
        fi
        cmake \
            ${CMAKE_GENERATOR+-G} "$CMAKE_GENERATOR" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=$PREFIX/$arch-w64-mingw32 \
            -DCMAKE_C_COMPILER=$arch-w64-mingw32-clang \
            -DCMAKE_CXX_COMPILER=$arch-w64-mingw32-clang++ \
            -DCMAKE_CROSSCOMPILING=TRUE \
            -DCMAKE_SYSTEM_NAME=Windows \
            -DCMAKE_C_COMPILER_WORKS=TRUE \
            -DCMAKE_CXX_COMPILER_WORKS=TRUE \
            -DLLVM_COMPILER_CHECKED=TRUE \
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
            -DCXX_SUPPORTS_CXX_STD=TRUE \
            -DCMAKE_CXX_FLAGS="$LIBCXXABI_VISIBILITY_FLAGS -D_LIBCPP_HAS_THREAD_API_WIN32 $extra_cflags" \
            ..
        make -j$CORES
        cd ..
    done
    cd ..

    cd libcxx
    for arch in $ARCHS; do
        mkdir -p $builddir
        cd $builddir
        if [ "$type" = "shared" ]; then
            LIBCXX_VISIBILITY_FLAGS="-D_LIBCXXABI_BUILDING_LIBRARY"
        else
            LIBCXX_VISIBILITY_FLAGS="-D_LIBCXXABI_DISABLE_VISIBILITY_ANNOTATIONS"
        fi
        if [ -n "$variant" ]; then
            install_headers=FALSE
        else
            install_headers=TRUE
        fi
        cmake \
            ${CMAKE_GENERATOR+-G} "$CMAKE_GENERATOR" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=$PREFIX/$arch-w64-mingw32 \
            -DCMAKE_C_COMPILER=$arch-w64-mingw32-clang \
            -DCMAKE_CXX_COMPILER=$arch-w64-mingw32-clang++ \
            -DCMAKE_CROSSCOMPILING=TRUE \
            -DCMAKE_SYSTEM_NAME=Windows \
            -DCMAKE_C_COMPILER_WORKS=TRUE \
            -DCMAKE_CXX_COMPILER_WORKS=TRUE \
            -DLLVM_COMPILER_CHECKED=TRUE \
            -DCMAKE_AR=$PREFIX/bin/llvm-ar \
            -DCMAKE_RANLIB=$PREFIX/bin/llvm-ranlib \
            -DLIBCXX_USE_COMPILER_RT=ON \
            -DLIBCXX_INSTALL_HEADERS=$install_headers \
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
            -DLIBCXX_CXX_ABI=libcxxabi \
            -DLIBCXX_CXX_ABI_INCLUDE_PATHS=../../libcxxabi/include \
            -DLIBCXX_CXX_ABI_LIBRARY_PATH=../../libcxxabi/$builddir/lib \
            -DLIBCXX_LIBDIR_SUFFIX="$subdir" \
            -DLIBCXX_INCLUDE_TESTS=FALSE \
            -DCMAKE_CXX_FLAGS="$LIBCXX_VISIBILITY_FLAGS $extra_cflags" \
            -DCMAKE_SHARED_LINKER_FLAGS="-lunwind -Wl,--export-all-symbols $extra_ldflags" \
            -DLIBCXX_ENABLE_ABI_LINKER_SCRIPT=FALSE \
            ..
        make -j$CORES
        make install
        if [ "$type" = "shared" ]; then
            llvm-ar qcsL \
                $PREFIX/$arch-w64-mingw32/lib/libc++.dll.a \
                $PREFIX/$arch-w64-mingw32/lib/libunwind.dll.a
            cp lib/libc++.dll $PREFIX/$arch-w64-mingw32/bin
        else
            llvm-ar qcsL \
                $PREFIX/$arch-w64-mingw32/lib$subdir/libc++.a \
                $PREFIX/$arch-w64-mingw32/lib$subdir/libunwind.a
        fi
        cd ..
    done
    cd ..
}

# Build shared first and static afterwards; the headers for static linking also
# work when linking against the DLL, but not vice versa.
[ -z "$BUILD_SHARED" ] || build_all shared
[ -z "$BUILD_STATIC" ] || build_all static

if [ -n "$BUILD_OTHER_CRT" ]; then
    cat<<EOF > is-ucrt.c
    #include <_mingw.h>
    #if __MSVCRT_VERSION__ < 0x1400
    #error not ucrt
    #endif
EOF
    ANY_ARCH=$(echo $ARCHS | awk '{print $1}')
    if $ANY_ARCH-w64-mingw32-gcc -E is-ucrt.c > /dev/null 2>&1; then
        CRT=ucrt
        OTHERCRT=msvcrt
        OTHERVER=0x700
        OTHERLIB=msvcrt-os
    else
        CRT=msvcrt
        OTHERCRT=ucrt
        OTHERVER=0x1400
        OTHERLIB=ucrt
    fi
    rm -f is-ucrt.c

    for arch in $ARCHS; do
        mkdir -p $PREFIX/$arch-w64-mingw32/lib/$CRT
        cp $PREFIX/$arch-w64-mingw32/lib/libc++.a $PREFIX/$arch-w64-mingw32/lib/$CRT
    done

    [ -z "$BUILD_STATIC" ] || build_all static $OTHERCRT "-D__MSVCRT_VERSION__=$OTHERVER" "-l$OTHERLIB"
fi
