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

: ${LLVM_REPOSITORY:=https://github.com/llvm/llvm-project.git}
: ${LLVM_VERSION:=llvmorg-21.1.8}
ASSERTS=OFF
unset HOST
BUILDDIR="build"
LINK_DYLIB=ON
ASSERTSSUFFIX=""
LLDB=ON
CLANG_TOOLS_EXTRA=ON
INSTRUMENTED=OFF

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
    --with-clang)
        WITH_CLANG=1
        BUILDDIR="$BUILDDIR-withclang"
        ;;
    --use-linker=*)
        USE_LINKER="${1#*=}"
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
    --disable-lldb)
        unset LLDB
        ;;
    --disable-clang-tools-extra)
        unset CLANG_TOOLS_EXTRA
        ;;
    --no-llvm-tool-reuse)
        NO_LLVM_TOOL_REUSE=1
        ;;
    --macos-native-tools)
        MACOS_NATIVE_TOOLS=1
        unset CLEAN
        ;;
    --instrumented|--instrumented=*)
        INSTRUMENTED="${1#--instrumented}"
        INSTRUMENTED="${INSTRUMENTED#=}"
        INSTRUMENTED="${INSTRUMENTED:-Frontend}"
        : ${LLVM_PROFILE_DATA_DIR:=/tmp/llvm-profile}
        # A fixed BUILDDIR is set at the end for this case.
        ;;
    --pgo|--pgo=*)
        LLVM_PROFDATA_FILE="${1#--pgo}"
        LLVM_PROFDATA_FILE="${LLVM_PROFDATA_FILE#=}"
        LLVM_PROFDATA_FILE="${LLVM_PROFDATA_FILE:-profile.profdata}"
        if [ ! -e "$LLVM_PROFDATA_FILE" ]; then
            echo Profile \"$LLVM_PROFDATA_FILE\" not found
            exit 1
        fi
        LLVM_PROFDATA_FILE="$(cd "$(dirname "$LLVM_PROFDATA_FILE")" && pwd)/$(basename "$LLVM_PROFDATA_FILE")"
        BUILDDIR="$BUILDDIR-pgo"
        ;;
    *)
        if [ -n "$PREFIX" ]; then
            echo Unrecognized parameter $1
            exit 1
        fi
        PREFIX="$1"
        ;;
    esac
    shift
done
BUILDDIR="$BUILDDIR$ASSERTSSUFFIX"
if [ -z "$CHECKOUT_ONLY" ]; then
    if [ -z "$PREFIX" ]; then
        echo $0 [--enable-asserts] [--with-clang] [--use-linker=linker] [--thinlto] [--lto] [--instrumented[=type]] [--pgo[=profile]] [--disable-dylib] [--full-llvm] [--with-python] [--disable-lldb] [--disable-clang-tools-extra] [--host=triple] [--no-llvm-tool-reuse] [--macos-native-tools] dest
        exit 1
    fi

    if [ "$INSTRUMENTED" = "OFF" ]; then
        mkdir -p "$PREFIX"
        PREFIX="$(cd "$PREFIX" && pwd)"
    fi
fi

if [ ! -d llvm-project ]; then
    mkdir llvm-project
    cd llvm-project
    git init
    git remote add origin "${LLVM_REPOSITORY}"
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

if [ -n "$HOST" ]; then
    case $HOST in
    *-mingw32)
        TARGET_WINDOWS=1
        ;;
    esac
else
    case $(uname) in
    MINGW*)
        TARGET_WINDOWS=1
        ;;
    esac
fi

if command -v ninja >/dev/null; then
    CMAKE_GENERATOR="Ninja"
else
    : ${CORES:=$(nproc 2>/dev/null)}
    : ${CORES:=$(sysctl -n hw.ncpu 2>/dev/null)}
    : ${CORES:=4}

    case $(uname) in
    MINGW*)
        CMAKE_GENERATOR="MSYS Makefiles"
        ;;
    esac
fi

CMAKEFLAGS="$LLVM_CMAKEFLAGS"

if [ -n "$HOST" ]; then
    ARCH="${HOST%%-*}"

    if [ -n "$WITH_CLANG" ]; then
        CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_C_COMPILER=clang"
        CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_CXX_COMPILER=clang++"
        CMAKEFLAGS="$CMAKEFLAGS -DLLVM_USE_LINKER=${USE_LINKER:-lld}"
        CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_ASM_COMPILER_TARGET=$HOST"
        CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_C_COMPILER_TARGET=$HOST"
        CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_CXX_COMPILER_TARGET=$HOST"
        if command -v $HOST-strip >/dev/null; then
            CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_STRIP=$(command -v $HOST-strip)"
        fi
    else
        CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_C_COMPILER=$HOST-gcc"
        CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_CXX_COMPILER=$HOST-g++"
        CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_SYSTEM_PROCESSOR=$ARCH"
    fi
    case $HOST in
    *-mingw32)
        CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_SYSTEM_NAME=Windows"
        CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_RC_COMPILER=$HOST-windres"
        ;;
    *-linux*)
        CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_SYSTEM_NAME=Linux"
        ;;
    *)
        echo "Unrecognized host $HOST"
        exit 1
        ;;
    esac

    native=""
    for dir in llvm-project/llvm/build/bin llvm-project/llvm/build-asserts/bin; do
        if [ -x "$dir/llvm-tblgen.exe" ]; then
            native="$(pwd)/$dir"
            break
        elif [ -x "$dir/llvm-tblgen" ]; then
            native="$(pwd)/$dir"
            break
        fi
    done
    if [ -z "$native" ] && command -v llvm-tblgen >/dev/null; then
        native="$(dirname $(command -v llvm-tblgen))"
    fi


    if [ -n "$native" ] && [ -z "$NO_LLVM_TOOL_REUSE" ]; then
        CMAKEFLAGS="$CMAKEFLAGS -DLLVM_NATIVE_TOOL_DIR=$native"
    fi
    CROSS_ROOT=$(cd $(dirname $(command -v $HOST-gcc))/../$HOST && pwd)
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_FIND_ROOT_PATH=$CROSS_ROOT"
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER"
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY"
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY"
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY"

    BUILDDIR=$BUILDDIR-$HOST

    if [ -n "$WITH_PYTHON" ] && [ -n "$TARGET_WINDOWS" ]; then
        # The python3-config script requires executing with bash. It outputs
        # an extra trailing space, which the extra 'echo' layer gets rid of.
        EXT_SUFFIX="$(echo $(bash $PREFIX/python/bin/python3-config --extension-suffix))"
        PYTHON_RELATIVE_PATH="$(cd "$PREFIX" && echo python/lib/python*/site-packages)"
        PYTHON_INCLUDE_DIR="$(echo $PREFIX/python/include/python*)"
        PYTHON_LIB="$(echo $PREFIX/python/lib/libpython3.*.dll.a)"
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
elif [ -n "$WITH_CLANG" ]; then
    # Build using clang and lld (from $PATH), rather than the system default
    # tools.
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_C_COMPILER=clang"
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_CXX_COMPILER=clang++"
    CMAKEFLAGS="$CMAKEFLAGS -DLLVM_USE_LINKER=${USE_LINKER:-lld}"
else
    # Native compilation with the system default compiler.

    # Use a faster linker, if available.
    if [ -n "$USE_LINKER" ]; then
        CMAKEFLAGS="$CMAKEFLAGS -DLLVM_USE_LINKER=$USE_LINKER"
    elif command -v ld.lld >/dev/null; then
        CMAKEFLAGS="$CMAKEFLAGS -DLLVM_USE_LINKER=lld"
    elif command -v ld.gold >/dev/null; then
        CMAKEFLAGS="$CMAKEFLAGS -DLLVM_USE_LINKER=gold"
    fi
fi

if [ -n "$COMPILER_LAUNCHER" ]; then
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_C_COMPILER_LAUNCHER=$COMPILER_LAUNCHER"
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_CXX_COMPILER_LAUNCHER=$COMPILER_LAUNCHER"
    # Make the LLVM build system set options for forcing relative paths
    # within the files, e.g. for source file references within assert
    # messages. This on its own isn't enough for making the cache reusable
    # across different worktrees though; one also needs to set the ccache
    # base_dir (CCACHE_BASEDIR) option. When setting that ccache option, this
    # option here doesn't really have any effect either, except for debug info.
    CMAKEFLAGS="$CMAKEFLAGS -DLLVM_USE_RELATIVE_PATHS_IN_FILES=ON"
fi

if [ -n "$LTO" ]; then
    CMAKEFLAGS="$CMAKEFLAGS -DLLVM_ENABLE_LTO=$LTO"
fi

if [ -n "$MACOS_REDIST" ]; then
    : ${MACOS_REDIST_ARCHS:=arm64 x86_64}
    : ${MACOS_REDIST_VERSION:=10.12}
    ARCH_LIST=""
    NATIVE=
    for arch in $MACOS_REDIST_ARCHS; do
        if [ -n "$ARCH_LIST" ]; then
            ARCH_LIST="$ARCH_LIST;"
        fi
        ARCH_LIST="$ARCH_LIST$arch"
        if [ "$(uname -m)" = "$arch" ]; then
            NATIVE=1
        fi
    done
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_OSX_ARCHITECTURES=$ARCH_LIST"
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_OSX_DEPLOYMENT_TARGET=$MACOS_REDIST_VERSION"
    if [ -z "$NATIVE" ]; then
        # If we're not building for the native arch, flag to CMake that we're
        # cross compiling, to let it build native versions of tools used
        # during the build.
        ARCH="$(echo $MACOS_REDIST_ARCHS | awk '{print $1}')"
        CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_SYSTEM_NAME=Darwin"
        CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_SYSTEM_PROCESSOR=$ARCH"
    fi
fi

if [ -z "$HOST" ] && [ "$(uname)" = "Darwin" ]; then
    if [ -n "$LLDB" ]; then
        # Building LLDB for macOS fails unless building libc++ is enabled at the
        # same time, or unless the LLDB tests are disabled.
        CMAKEFLAGS="$CMAKEFLAGS -DLLDB_INCLUDE_TESTS=OFF"
        # Don't build our own debugserver - use the system provided one.
        # The newly built debugserver needs to be properly code signed to work.
        # This silences a cmake warning.
        CMAKEFLAGS="$CMAKEFLAGS -DLLDB_USE_SYSTEM_DEBUGSERVER=ON"
    fi
    if [ -n "$WITH_CLANG" ] && [ -n "$LTO" ]; then
        # If doing LTO, we need to make sure other related tools are used.
        # CMAKE_LIBTOOL is not a standard cmake tool, but an LLVM specific
        # thing. It defaults to looking up the tool with xcrun rather than
        # looking in paths first.
        # If building for multiple architectures at once
        # (CMAKE_OSX_ARCHITECTURES), we also need to provide a tool named
        # "lipo" in the PATH (this is invoked by Clang directly, so we can't
        # specify it here unless we pass in the option "-fuse-lipo="). If
        # the LLVM CMake build wasn't using libtool, we would also need to
        # specify LLVM_AR and LLVM_RANLIB.
        CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_LIBTOOL=$(command -v llvm-libtool-darwin)"
    fi
fi

if [ "$INSTRUMENTED" != "OFF" ]; then
    # For instrumented build, use a hardcoded builddir that we can
    # locate, and don't install the built files.
    BUILDDIR="build-instrumented"
fi

TOOLCHAIN_ONLY=ON
if [ -n "$FULL_LLVM" ]; then
    TOOLCHAIN_ONLY=OFF
fi

cd llvm-project/llvm

PROJECTS="clang;lld"
if [ -n "$LLDB" ]; then
    PROJECTS="$PROJECTS;lldb"
fi
if [ -n "$CLANG_TOOLS_EXTRA" ]; then
    PROJECTS="$PROJECTS;clang-tools-extra"
fi

[ -z "$CLEAN" ] || rm -rf $BUILDDIR
mkdir -p $BUILDDIR
cd $BUILDDIR

if [ -n "$MACOS_NATIVE_TOOLS" ]; then
    # Build tools needed for targeting macOS with LTO.
    #
    # The install-<tool>(-stripped) targets are unavailable for
    # tools that are excluded due to LLVM_INSTALL_TOOLCHAIN_ONLY=ON and
    # LLVM_TOOLCHAIN_TOOLS, so install those manually.
    cmake --build . --target llvm-lipo --target llvm-libtool-darwin
    # Install ld64.lld, required for -fuse-ld=lld
    cmake --install . --strip --component lld
    # Install llvm-libtool-darwin and lipo, needed for building with LTO.
    # See the comment further above for more details about this.
    cp bin/llvm-lipo bin/llvm-libtool-darwin $PREFIX/bin
    strip $PREFIX/bin/llvm-lipo $PREFIX/bin/llvm-libtool-darwin
    ln -sf llvm-lipo $PREFIX/bin/lipo
    exit 0
fi

[ -n "$NO_RECONF" ] || rm -rf CMake*
cmake \
    ${CMAKE_GENERATOR+-G} "$CMAKE_GENERATOR" \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLVM_ENABLE_ASSERTIONS=$ASSERTS \
    -DLLVM_ENABLE_PROJECTS="$PROJECTS" \
    -DLLVM_ENABLE_BINDINGS=OFF \
    -DLLVM_TARGETS_TO_BUILD="ARM;AArch64;X86;NVPTX" \
    -DLLVM_INSTALL_TOOLCHAIN_ONLY=$TOOLCHAIN_ONLY \
    -DLLVM_LINK_LLVM_DYLIB=$LINK_DYLIB \
    -DLLVM_TOOLCHAIN_TOOLS="llvm-ar;llvm-ranlib;llvm-objdump;llvm-rc;llvm-cvtres;llvm-nm;llvm-strings;llvm-readobj;llvm-dlltool;llvm-pdbutil;llvm-objcopy;llvm-strip;llvm-cov;llvm-profdata;llvm-addr2line;llvm-symbolizer;llvm-windres;llvm-ml;llvm-readelf;llvm-size;llvm-cxxfilt;llvm-lib" \
    ${HOST+-DLLVM_HOST_TRIPLE=$HOST} \
    -DLLVM_BUILD_INSTRUMENTED=$INSTRUMENTED \
    ${LLVM_PROFILE_DATA_DIR+-DLLVM_PROFILE_DATA_DIR=$LLVM_PROFILE_DATA_DIR} \
    ${LLVM_PROFDATA_FILE+-DLLVM_PROFDATA_FILE=$LLVM_PROFDATA_FILE} \
    $CMAKEFLAGS \
    ..

if [ "$INSTRUMENTED" != "OFF" ]; then
    # For instrumented builds, don't install the built files (so $PREFIX
    # is entirely unused).
    cmake --build . ${CORES:+-j${CORES}} --target clang --target lld
else
    cmake --build . ${CORES:+-j${CORES}}
    cmake --install . --strip

    cp ../LICENSE.TXT $PREFIX
fi
