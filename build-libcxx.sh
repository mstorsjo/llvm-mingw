#!/bin/sh
#
# Copyright (c) 2018 Martin Storsjo
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

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

mkdir -p "$PREFIX"
PREFIX="$(cd "$PREFIX" && pwd)"

export PATH="$PREFIX/bin:$PATH"

: ${ARCHS:=${TOOLCHAIN_ARCHS-i686 x86_64 armv7 aarch64}}

if [ ! -d llvm-project/libunwind ] || [ -n "$SYNC" ]; then
    CHECKOUT_ONLY=1 ./build-llvm.sh
fi

cd llvm-project

LLVM_PATH="$(pwd)/llvm"

if [ -n "$(which ninja)" ]; then
    CMAKE_GENERATOR="Ninja"
    NINJA=1
    BUILDCMD=ninja
else
    : ${CORES:=$(nproc 2>/dev/null)}
    : ${CORES:=$(sysctl -n hw.ncpu 2>/dev/null)}
    : ${CORES:=4}

    case $(uname) in
    MINGW*)
        CMAKE_GENERATOR="MSYS Makefiles"
        ;;
    *)
        ;;
    esac
    BUILDCMD=make
fi

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
        [ -z "$CLEAN" ] || rm -rf build-$arch-$type
        mkdir -p build-$arch-$type
        cd build-$arch-$type
        # CXX_SUPPORTS_CXX11 is not strictly necessary here. But if building
        # with a stripped llvm install, and the system happens to have an older
        # llvm-config in /usr/bin, it can end up including older cmake files,
        # and then CXX_SUPPORTS_CXX11 needs to be set.
        cmake \
            ${CMAKE_GENERATOR+-G} "$CMAKE_GENERATOR" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX="$PREFIX/$arch-w64-mingw32" \
            -DCMAKE_C_COMPILER=$arch-w64-mingw32-clang \
            -DCMAKE_CXX_COMPILER=$arch-w64-mingw32-clang++ \
            -DCMAKE_CROSSCOMPILING=TRUE \
            -DCMAKE_SYSTEM_NAME=Windows \
            -DCMAKE_C_COMPILER_WORKS=TRUE \
            -DCMAKE_CXX_COMPILER_WORKS=TRUE \
            -DLLVM_PATH="$LLVM_PATH" \
            -DLLVM_COMPILER_CHECKED=TRUE \
            -DCMAKE_AR="$PREFIX/bin/llvm-ar" \
            -DCMAKE_RANLIB="$PREFIX/bin/llvm-ranlib" \
            -DCXX_SUPPORTS_CXX11=TRUE \
            -DCXX_SUPPORTS_CXX_STD=TRUE \
            -DLIBUNWIND_USE_COMPILER_RT=TRUE \
            -DLIBUNWIND_ENABLE_THREADS=TRUE \
            -DLIBUNWIND_ENABLE_SHARED=$SHARED \
            -DLIBUNWIND_ENABLE_STATIC=$STATIC \
            -DLIBUNWIND_ENABLE_CROSS_UNWINDING=FALSE \
            -DCMAKE_CXX_FLAGS="-Wno-dll-attribute-on-redeclaration" \
            -DCMAKE_C_FLAGS="-Wno-dll-attribute-on-redeclaration" \
            ..
        $BUILDCMD ${CORES+-j$CORES}
        $BUILDCMD install
        if [ "$type" = "shared" ]; then
            mkdir -p "$PREFIX/$arch-w64-mingw32/bin"
            cp lib/libunwind.dll "$PREFIX/$arch-w64-mingw32/bin"
        fi
        cd ..
    done
    cd ..

    # Configure, but don't build, libcxx, so that libcxxabi has
    # proper headers to refer to
    cd libcxx
    for arch in $ARCHS; do
        [ -z "$CLEAN" ] || rm -rf build-$arch-$type
        mkdir -p build-$arch-$type
        cd build-$arch-$type
        if [ "$type" = "shared" ]; then
            LIBCXX_VISIBILITY_FLAGS="-D_LIBCXXABI_BUILDING_LIBRARY"
        else
            LIBCXX_VISIBILITY_FLAGS="-D_LIBCXXABI_DISABLE_VISIBILITY_ANNOTATIONS"
        fi
        cmake \
            ${CMAKE_GENERATOR+-G} "$CMAKE_GENERATOR" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX="$PREFIX/$arch-w64-mingw32" \
            -DCMAKE_C_COMPILER=$arch-w64-mingw32-clang \
            -DCMAKE_CXX_COMPILER=$arch-w64-mingw32-clang++ \
            -DCMAKE_CROSSCOMPILING=TRUE \
            -DCMAKE_SYSTEM_NAME=Windows \
            -DCMAKE_C_COMPILER_WORKS=TRUE \
            -DCMAKE_CXX_COMPILER_WORKS=TRUE \
            -DLLVM_COMPILER_CHECKED=TRUE \
            -DCMAKE_AR="$PREFIX/bin/llvm-ar" \
            -DCMAKE_RANLIB="$PREFIX/bin/llvm-ranlib" \
            -DLLVM_PATH="$LLVM_PATH" \
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
            -DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=TRUE \
            -DLIBCXX_ENABLE_NEW_DELETE_DEFINITIONS=ON \
            -DLIBCXX_CXX_ABI=libcxxabi \
            -DLIBCXX_CXX_ABI_INCLUDE_PATHS=../../libcxxabi/include \
            -DLIBCXX_CXX_ABI_LIBRARY_PATH=../../libcxxabi/build-$arch-$type/lib \
            -DLIBCXX_LIBDIR_SUFFIX="" \
            -DLIBCXX_INCLUDE_TESTS=FALSE \
            -DCMAKE_CXX_FLAGS="$LIBCXX_VISIBILITY_FLAGS" \
            -DCMAKE_SHARED_LINKER_FLAGS="-lunwind" \
            -DLIBCXX_ENABLE_ABI_LINKER_SCRIPT=FALSE \
            ..
        $BUILDCMD ${CORES+-j$CORES} generate-cxx-headers
        cd ..
    done
    cd ..

    cd libcxxabi
    for arch in $ARCHS; do
        [ -z "$CLEAN" ] || rm -rf build-$arch-$type
        mkdir -p build-$arch-$type
        cd build-$arch-$type
        if [ "$type" = "shared" ]; then
            LIBCXXABI_VISIBILITY_FLAGS="-D_LIBCPP_BUILDING_LIBRARY= -U_LIBCXXABI_DISABLE_VISIBILITY_ANNOTATIONS"
        else
            LIBCXXABI_VISIBILITY_FLAGS=""
        fi
        cmake \
            ${CMAKE_GENERATOR+-G} "$CMAKE_GENERATOR" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX="$PREFIX/$arch-w64-mingw32" \
            -DCMAKE_C_COMPILER=$arch-w64-mingw32-clang \
            -DCMAKE_CXX_COMPILER=$arch-w64-mingw32-clang++ \
            -DCMAKE_CROSSCOMPILING=TRUE \
            -DCMAKE_SYSTEM_NAME=Windows \
            -DCMAKE_C_COMPILER_WORKS=TRUE \
            -DCMAKE_CXX_COMPILER_WORKS=TRUE \
            -DLLVM_PATH="$LLVM_PATH" \
            -DLLVM_COMPILER_CHECKED=TRUE \
            -DCMAKE_AR="$PREFIX/bin/llvm-ar" \
            -DCMAKE_RANLIB="$PREFIX/bin/llvm-ranlib" \
            -DLIBCXXABI_USE_COMPILER_RT=ON \
            -DLIBCXXABI_ENABLE_EXCEPTIONS=ON \
            -DLIBCXXABI_ENABLE_THREADS=ON \
            -DLIBCXXABI_TARGET_TRIPLE=$arch-w64-mingw32 \
            -DLIBCXXABI_ENABLE_SHARED=OFF \
            -DLIBCXXABI_LIBCXX_INCLUDES=../../libcxx/build-$arch-$type/include/c++/v1 \
            -DLIBCXXABI_LIBDIR_SUFFIX="" \
            -DLIBCXXABI_ENABLE_NEW_DELETE_DEFINITIONS=OFF \
            -DCXX_SUPPORTS_CXX_STD=TRUE \
            -DCMAKE_CXX_FLAGS="$LIBCXXABI_VISIBILITY_FLAGS" \
            ..
        $BUILDCMD ${CORES+-j$CORES}
        cd ..
    done
    cd ..

    cd libcxx
    for arch in $ARCHS; do
        cd build-$arch-$type
        $BUILDCMD ${CORES+-j$CORES}
        $BUILDCMD install
        if [ "$type" = "shared" ]; then
            llvm-ar qcsL \
                "$PREFIX/$arch-w64-mingw32/lib/libc++.dll.a" \
                "$PREFIX/$arch-w64-mingw32/lib/libunwind.dll.a"
            cp lib/libc++.dll "$PREFIX/$arch-w64-mingw32/bin"
        else
            llvm-ar qcsL \
                "$PREFIX/$arch-w64-mingw32/lib/libc++.a" \
                "$PREFIX/$arch-w64-mingw32/lib/libunwind.a"
        fi
        cd ..
    done
    cd ..
}

# Build shared first and static afterwards; the headers for static linking also
# work when linking against the DLL, but not vice versa.
[ -z "$BUILD_SHARED" ] || build_all shared
[ -z "$BUILD_STATIC" ] || build_all static
