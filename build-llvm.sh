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

: ${LLVM_VERSION:=156136502b73a53192f21fc0477263e76a17a9b9}
ASSERTS=OFF
unset HOST
BUILDDIR="build"
LINK_DYLIB=ON
ASSERTSSUFFIX=""
LLDB=ON
CLANG_TOOLS_EXTRA=ON

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
    --symlink-projects)
        SYMLINK_PROJECTS=1
        ;;
    --disable-lldb)
        unset LLDB
        ;;
    --disable-clang-tools-extra)
        unset CLANG_TOOLS_EXTRA
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
        echo $0 [--enable-asserts] [--stage2] [--thinlto] [--lto] [--disable-dylib] [--full-llvm] [--with-python] [--symlink-projects] [--disable-lldb] [--disable-clang-tools-extra] [--host=triple] dest
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
    cd ..
    CHECKOUT=1
fi

if [ -n "$SYNC" ] || [ -n "$CHECKOUT" ]; then
    cd llvm-project
    # Check if the intended commit or tag exists in the local repo. If it
    # exists, just check it out instead of trying to fetch it.
    # (Redoing a shallow fetch will refetch the data even if the commit
    # already exists locally, unless fetching a tag with the "tag"
    # argument.)
    if git cat-file -e "$LLVM_VERSION" 2> /dev/null; then
        # Exists; just check it out
        git checkout "$LLVM_VERSION"
    else
        case "$LLVM_VERSION" in
        llvmorg-*)
            # If $LLVM_VERSION looks like a tag, fetch it with the
            # "tag" keyword. This makes sure that the local repo
            # gets the tag too, not only the commit itself. This allows
            # later fetches to realize that the tag already exists locally.
            git fetch --depth 1 origin tag "$LLVM_VERSION"
            git checkout "$LLVM_VERSION"
            ;;
        *)
            git fetch --depth 1 origin "$LLVM_VERSION"
            git checkout FETCH_HEAD
            ;;
        esac
    fi
    cd ..
fi

[ -z "$CHECKOUT_ONLY" ] || exit 0

if command -v ninja >/dev/null; then
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

CMAKEFLAGS="$LLVM_CMAKEFLAGS"

if [ -n "$HOST" ]; then
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_SYSTEM_NAME=Windows"
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_C_COMPILER=$HOST-gcc"
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_CXX_COMPILER=$HOST-g++"
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_RC_COMPILER=$HOST-windres"

    native=""
    for dir in llvm-project/llvm/build/bin llvm-project/llvm/build-asserts/bin; do
        if [ -x "$dir/llvm-tblgen.exe" ]; then
            native="$(pwd)/$dir"
            suffix=".exe"
            break
        elif [ -x "$dir/llvm-tblgen" ]; then
            native="$(pwd)/$dir"
            suffix=""
            break
        fi
    done
    if [ -z "$native" ] && command -v llvm-tblgen >/dev/null; then
        native="$(dirname $(command -v llvm-tblgen))"
        suffix=""
        if [ -x "$native/llvm-tblgen.exe" ]; then
            suffix=".exe"
        fi
    fi


    if [ -n "$native" ]; then
        if [ -x "$native/llvm-tblgen$suffix" ]; then
            CMAKEFLAGS="$CMAKEFLAGS -DLLVM_TABLEGEN=$native/llvm-tblgen$suffix"
        fi
        if [ -x "$native/clang-tblgen$suffix" ]; then
            CMAKEFLAGS="$CMAKEFLAGS -DCLANG_TABLEGEN=$native/clang-tblgen$suffix"
        fi
        if [ -x "$native/lldb-tblgen$suffix" ]; then
            CMAKEFLAGS="$CMAKEFLAGS -DLLDB_TABLEGEN=$native/lldb-tblgen$suffix"
        fi
        if [ -x "$native/llvm-config$suffix" ]; then
            CMAKEFLAGS="$CMAKEFLAGS -DLLVM_CONFIG_PATH=$native/llvm-config$suffix"
        fi
        if [ -x "$native/clang-pseudo-gen$suffix" ]; then
            CMAKEFLAGS="$CMAKEFLAGS -DCLANG_PSEUDO_GEN=$native/clang-pseudo-gen$suffix"
        fi
        if [ -x "$native/clang-tidy-confusable-chars-gen$suffix" ]; then
            CMAKEFLAGS="$CMAKEFLAGS -DCLANG_TIDY_CONFUSABLE_CHARS_GEN=$native/clang-tidy-confusable-chars-gen$suffix"
        fi
    fi
    CROSS_ROOT=$(cd $(dirname $(command -v $HOST-gcc))/../$HOST && pwd)
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_FIND_ROOT_PATH=$CROSS_ROOT"
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER"
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY"
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY"
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY"

    # Custom, llvm-mingw specific defaults. We normally set these in
    # the frontend wrappers, but this makes sure they are enabled by
    # default if that wrapper is bypassed as well.
    CMAKEFLAGS="$CMAKEFLAGS -DCLANG_DEFAULT_RTLIB=compiler-rt"
    CMAKEFLAGS="$CMAKEFLAGS -DCLANG_DEFAULT_UNWINDLIB=libunwind"
    CMAKEFLAGS="$CMAKEFLAGS -DCLANG_DEFAULT_CXX_STDLIB=libc++"
    CMAKEFLAGS="$CMAKEFLAGS -DCLANG_DEFAULT_LINKER=lld"
    BUILDDIR=$BUILDDIR-$HOST

    if [ -n "$WITH_PYTHON" ]; then
        # The python3-config script requires executing with bash. It outputs
        # an extra trailing space, which the extra 'echo' layer gets rid of.
        EXT_SUFFIX="$(echo $(bash $PREFIX/python/bin/python3-config --extension-suffix))"
        PYTHON_RELATIVE_PATH="$(cd "$PREFIX" && echo python/lib/python*/site-packages)"
        PYTHON_INCLUDE_DIR="$(echo $PREFIX/python/include/python*)"
        PYTHON_LIB="$(echo $PREFIX/python/lib/libpython*.dll.a)"
        CMAKEFLAGS="$CMAKEFLAGS -DLLDB_ENABLE_PYTHON=ON"
        CMAKEFLAGS="$CMAKEFLAGS -DPYTHON_HOME=$PREFIX/python"
        CMAKEFLAGS="$CMAKEFLAGS -DLLDB_PYTHON_HOME=../python"
        # Relative to the lldb install root
        CMAKEFLAGS="$CMAKEFLAGS -DLLDB_PYTHON_RELATIVE_PATH=$PYTHON_RELATIVE_PATH"
        # Relative to LLDB_PYTHON_HOME
        CMAKEFLAGS="$CMAKEFLAGS -DLLDB_PYTHON_EXE_RELATIVE_PATH=bin/python3.exe"
        CMAKEFLAGS="$CMAKEFLAGS -DLLDB_PYTHON_EXT_SUFFIX=$EXT_SUFFIX"

        CMAKEFLAGS="$CMAKEFLAGS -DPython3_INCLUDE_DIRS=$PYTHON_INCLUDE_DIR"
        CMAKEFLAGS="$CMAKEFLAGS -DPython3_LIBRARIES=$PYTHON_LIB"
    fi
elif [ -n "$STAGE2" ]; then
    # Build using an earlier built and installed clang in the target directory
    export PATH="$PREFIX/bin:$PATH"
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_C_COMPILER=clang"
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_CXX_COMPILER=clang++"
    CMAKEFLAGS="$CMAKEFLAGS -DLLVM_USE_LINKER=lld"
fi

if [ -n "$LTO" ]; then
    CMAKEFLAGS="$CMAKEFLAGS -DLLVM_ENABLE_LTO=$LTO"
fi

if [ -n "$MACOS_REDIST" ]; then
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_OSX_ARCHITECTURES=arm64;x86_64"
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_OSX_DEPLOYMENT_TARGET=10.9"
fi

TOOLCHAIN_ONLY=ON
if [ -n "$FULL_LLVM" ]; then
    TOOLCHAIN_ONLY=OFF
fi

cd llvm-project/llvm

if [ -n "$SYMLINK_PROJECTS" ]; then
    # If requested, hook up other tools by symlinking them into tools,
    # instead of using LLVM_ENABLE_PROJECTS. This way, all source code is
    # under the directory tree of the toplevel cmake file (llvm-project/llvm),
    # which makes cmake use relative paths to all source files. Using relative
    # paths makes for identical compiler output from different source trees in
    # different locations (for cases where e.g. path names are included, in
    # assert messages), allowing ccache to share caches across multiple
    # checkouts.
    cd tools
    for p in clang lld lldb; do
        if [ "$p" = "lldb" ] && [ -z "$LLDB" ]; then
            continue
        fi
        if [ ! -e $p ]; then
            ln -s ../../$p .
        fi
    done
    cd ..
    if [ -n "$CLANG_TOOLS_EXTRA" ]; then
        cd ../clang/tools
        if [ ! -e extra ]; then
            ln -s ../../clang-tools-extra extra
        fi
        cd ../../llvm
    fi
else
    EXPLICIT_PROJECTS=1
    PROJECTS="clang;lld"
    if [ -n "$LLDB" ]; then
        PROJECTS="$PROJECTS;lldb"
    fi
    if [ -n "$CLANG_TOOLS_EXTRA" ]; then
        PROJECTS="$PROJECTS;clang-tools-extra"
    fi
fi

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
    ${EXPLICIT_PROJECTS+-DLLVM_ENABLE_PROJECTS="$PROJECTS"} \
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
