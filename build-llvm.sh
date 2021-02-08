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

: ${LLVM_VERSION:=llvmorg-13.0.0-rc1}
ASSERTS=OFF
unset HOST
BUILDDIR="build"
LINK_DYLIB=ON
ASSERTSSUFFIX=""

while [ $# -gt 0 ]; do
    case "$1" in
    --disable-asserts)
        ASSERTS=OFF
        ASSERTSSUFFIX=""
        ;;
    --enable-asserts)
        ASSERTS=ON
        ASSERTSSUFFIX="-asserts"
        ;;
    --stage2)
        STAGE2=1
        BUILDDIR="$BUILDDIR-stage2"
        ;;
    --thinlto)
        LTO="thin"
        BUILDDIR="$BUILDDIR-thinlto"
        ;;
    --lto)
        LTO="full"
        BUILDDIR="$BUILDDIR-lto"
        ;;
    --disable-dylib)
        LINK_DYLIB=OFF
        ;;
    --full-llvm)
        FULL_LLVM=1
        ;;
    --host=*)
        HOST="${1#*=}"
        ;;
    --with-python)
        WITH_PYTHON=1
        ;;
    *)
        PREFIX="$1"
        ;;
    esac
    shift
done
BUILDDIR="$BUILDDIR$ASSERTSSUFFIX"
if [ -z "$CHECKOUT_ONLY" ]; then
    if [ -z "$PREFIX" ]; then
        echo $0 [--enable-asserts] [--stage2] [--thinlto] [--lto] [--disable-dylib] [--full-llvm] [--with-python] [--host=triple] dest
        exit 1
    fi

    mkdir -p "$PREFIX"
    PREFIX="$(cd "$PREFIX" && pwd)"
fi

if [ ! -d llvm-project ]; then
    mkdir llvm-project
    cd llvm-project
    git init
    git remote add origin https://github.com/llvm/llvm-project.git
    git fetch --depth 1 origin "$LLVM_VERSION"
    git checkout FETCH_HEAD
    cd ..
    CHECKOUT=1
    unset SYNC
fi

if [ -n "$SYNC" ] || [ -n "$CHECKOUT" ]; then
    cd llvm-project
    if [ -n "$SYNC" ]; then 
        git fetch --depth 1 origin "$LLVM_VERSION"
        git checkout FETCH_HEAD
    fi
    cd ..
fi

[ -z "$CHECKOUT_ONLY" ] || exit 0

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

if [ -n "$HOST" ]; then
    find_native_tools() {
        if [ -d llvm-project/llvm/build/bin ]; then
            echo $(pwd)/llvm-project/llvm/build/bin
        elif [ -d llvm-project/llvm/build-asserts/bin ]; then
            echo $(pwd)/llvm-project/llvm/build-asserts/bin
        elif [ -d llvm-project/llvm/build-noasserts/bin ]; then
            echo $(pwd)/llvm-project/llvm/build-noasserts/bin
        elif [ -n "$(which llvm-tblgen)" ]; then
            echo $(dirname $(which llvm-tblgen))
        fi
    }

    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_SYSTEM_NAME=Windows"
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_CROSSCOMPILING=TRUE"
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_C_COMPILER=$HOST-gcc"
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_CXX_COMPILER=$HOST-g++"
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_RC_COMPILER=$HOST-windres"
    CMAKEFLAGS="$CMAKEFLAGS -DCROSS_TOOLCHAIN_FLAGS_NATIVE="

    native=$(find_native_tools)
    if [ -n "$native" ]; then
        suffix=""
        if [ -f $native/llvm-tblgen.exe ]; then
            suffix=".exe"
        fi
        CMAKEFLAGS="$CMAKEFLAGS -DLLVM_TABLEGEN=$native/llvm-tblgen$suffix"
        CMAKEFLAGS="$CMAKEFLAGS -DCLANG_TABLEGEN=$native/clang-tblgen$suffix"
        CMAKEFLAGS="$CMAKEFLAGS -DLLDB_TABLEGEN=$native/lldb-tblgen$suffix"
        CMAKEFLAGS="$CMAKEFLAGS -DLLVM_CONFIG_PATH=$native/llvm-config$suffix"
    fi
    CROSS_ROOT=$(cd $(dirname $(which $HOST-gcc))/../$HOST && pwd)
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_FIND_ROOT_PATH=$CROSS_ROOT"
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER"
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY"
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY"

    # Custom, llvm-mingw specific defaults. We normally set these in
    # the frontend wrappers, but this makes sure they are enabled by
    # default if that wrapper is bypassed as well.
    CMAKEFLAGS="$CMAKEFLAGS -DCLANG_DEFAULT_RTLIB=compiler-rt"
    CMAKEFLAGS="$CMAKEFLAGS -DCLANG_DEFAULT_CXX_STDLIB=libc++"
    CMAKEFLAGS="$CMAKEFLAGS -DCLANG_DEFAULT_LINKER=lld"
    BUILDDIR=$BUILDDIR-$HOST

    if [ -n "$WITH_PYTHON" ]; then
        PYTHON_VER="3.9"
        CMAKEFLAGS="$CMAKEFLAGS -DLLDB_ENABLE_PYTHON=ON"
        [ -z "$PYTHON_EXEC" ] && command -v python$PYTHON_VER && PYTHON_EXEC=python$PYTHON_VER
        [ -z "$PYTHON_EXEC" ] && command -v python3           && PYTHON_EXEC=python3
        [ -z "$PYTHON_EXEC" ] && command -v python            && PYTHON_EXEC=python
        CMAKEFLAGS="$CMAKEFLAGS -DPYTHON_HOME=$PREFIX/python"
        CMAKEFLAGS="$CMAKEFLAGS -DLLDB_PYTHON_HOME=../python"
        CMAKEFLAGS="$CMAKEFLAGS -DLLDB_PYTHON_RELATIVE_PATH=python/lib/python$PYTHON_VER/site-packages"

        CMAKEFLAGS="$CMAKEFLAGS -DPython3_EXECUTABLE=$PYTHON_EXEC"
        CMAKEFLAGS="$CMAKEFLAGS -DPython3_INCLUDE_DIRS=$PREFIX/python/include/python$PYTHON_VER"
        CMAKEFLAGS="$CMAKEFLAGS -DPython3_LIBRARIES=$PREFIX/python/lib/libpython$PYTHON_VER.dll.a"
    fi
elif [ -n "$STAGE2" ]; then
    # Build using an earlier built and installed clang in the target directory
    export PATH="$PREFIX/bin:$PATH"
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_C_COMPILER=clang"
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_CXX_COMPILER=clang++"
    if [ "$(uname)" != "Darwin" ]; then
        # Current lld isn't yet properly usable on macOS
        CMAKEFLAGS="$CMAKEFLAGS -DLLVM_USE_LINKER=lld"
    fi
fi

if [ -n "$LTO" ]; then
    CMAKEFLAGS="$CMAKEFLAGS -DLLVM_ENABLE_LTO=$LTO"
fi

TOOLCHAIN_ONLY=ON
if [ -n "$FULL_LLVM" ]; then
    TOOLCHAIN_ONLY=OFF
fi

cd llvm-project/llvm

case $(uname) in
MINGW*)
    EXPLICIT_PROJECTS=1
    ;;
*)
    # If we have working symlinks, hook up other tools by symlinking them
    # into tools, instead of using LLVM_ENABLE_PROJECTS. This way, all
    # source code is under the directory tree of the toplevel cmake file
    # (llvm-project/llvm), which makes cmake use relative paths to all source
    # files. Using relative paths makes for identical compiler output from
    # different source trees in different locations (for cases where e.g.
    # path names are included, in assert messages), allowing ccache to speed
    # up compilation.
    cd tools
    for p in clang lld lldb; do
        if [ ! -e $p ]; then
            ln -s ../../$p .
        fi
    done
    cd ..
    ;;
esac

[ -z "$CLEAN" ] || rm -rf $BUILDDIR
mkdir -p $BUILDDIR
cd $BUILDDIR
# Building LLDB for macOS fails unless building libc++ is enabled at the
# same time, or unless the LLDB tests are disabled.
cmake \
    ${CMAKE_GENERATOR+-G} "$CMAKE_GENERATOR" \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLVM_ENABLE_ASSERTIONS=$ASSERTS \
    ${EXPLICIT_PROJECTS+-DLLVM_ENABLE_PROJECTS="clang;lld;lldb"} \
    -DLLVM_TARGETS_TO_BUILD="ARM;AArch64;X86" \
    -DLLVM_INSTALL_TOOLCHAIN_ONLY=$TOOLCHAIN_ONLY \
    -DLLVM_LINK_LLVM_DYLIB=$LINK_DYLIB \
    -DLLVM_TOOLCHAIN_TOOLS="llvm-ar;llvm-ranlib;llvm-objdump;llvm-rc;llvm-cvtres;llvm-nm;llvm-strings;llvm-readobj;llvm-dlltool;llvm-pdbutil;llvm-objcopy;llvm-strip;llvm-cov;llvm-profdata;llvm-addr2line;llvm-symbolizer;llvm-windres;llvm-ml;llvm-readelf" \
    ${HOST+-DLLVM_HOST_TRIPLE=$HOST} \
    -DLLDB_INCLUDE_TESTS=OFF \
    $CMAKEFLAGS \
    ..

$BUILDCMD ${CORES+-j$CORES} install/strip

cp ../LICENSE.TXT $PREFIX
