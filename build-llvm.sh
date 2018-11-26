#!/bin/sh

set -e

ASSERTS=OFF
BUILDDIR=build

while [ $# -gt 0 ]; do
    if [ "$1" = "--disable-asserts" ]; then
        ASSERTS=OFF
        BUILDDIR=build
    elif [ "$1" = "--enable-asserts" ]; then
        ASSERTS=ON
        BUILDDIR=build-asserts
    else
        PREFIX="$1"
    fi
    shift
done
if [ -z "$PREFIX" ]; then
    echo $0 [--enable-asserts] dest
    exit 1
fi

mkdir -p "$PREFIX"
PREFIX="$(cd "$PREFIX" && pwd)"

: ${CORES:=$(nproc 2>/dev/null)}
: ${CORES:=$(sysctl -n hw.ncpu 2>/dev/null)}
: ${CORES:=4}

if [ ! -d llvm ]; then
    # When cloning master and checking out a pinned old hash, we can't use --depth=1.
    # Do the git-svn rebase to populate git-svn information, to make
    # "clang --version" produce SVN based version numbers.
    git clone -b master https://github.com/llvm-mirror/llvm.git
    cd llvm/tools
    git clone -b master https://github.com/llvm-mirror/clang.git
    git clone -b master https://github.com/llvm-mirror/lld.git
    cd ..
    git svn init https://llvm.org/svn/llvm-project/llvm/trunk
    git config svn-remote.svn.fetch :refs/remotes/origin/master
    git svn rebase -l
    cd tools/clang
    git svn init https://llvm.org/svn/llvm-project/cfe/trunk
    git config svn-remote.svn.fetch :refs/remotes/origin/master
    git svn rebase -l
    cd ../lld
    git svn init https://llvm.org/svn/llvm-project/lld/trunk
    git config svn-remote.svn.fetch :refs/remotes/origin/master
    git svn rebase -l
    cd ../../..
    CHECKOUT=1
fi

if [ -n "$SYNC" ] || [ -n "$CHECKOUT" ]; then
    cd llvm
    [ -z "$SYNC" ] || git fetch
    git checkout 0bd2b610127f5d2d7dae5cb7f4e705709cf4612d
    cd tools/clang
    [ -z "$SYNC" ] || git fetch
    git checkout 45b5be68b31579b7db8ef0b954fe5e67cc840c2f
    cd ../lld
    [ -z "$SYNC" ] || git fetch
    git checkout 5500a785ffcc416cee19f4460b877250cde8129a
    cd ../../..
fi

if [ -n "$(which ninja)" ]; then
    CMAKE_GENERATOR="Ninja"
    NINJA=1
else
    case $(uname) in
    MINGW*)
        CMAKE_GENERATOR="MSYS Makefiles"
        ;;
    *)
        ;;
    esac
fi

if [ -n "$HOST" ]; then
    find_native_tools() {
        if [ -d llvm/build/bin ]; then
            echo $(pwd)/llvm/build/bin
        elif [ -d llvm/build-asserts/bin ]; then
            echo $(pwd)/llvm/build-asserts/bin
        elif [ -d llvm/build-noasserts/bin ]; then
            echo $(pwd)/llvm/build-noasserts/bin
        elif [ -n "$(which llvm-tblgen)" ]; then
            echo $(dirname $(which llvm-tblgen))
        fi
    }
    native=$(find_native_tools)
    if [ -z "$native" ]; then
        # As we don't do any install here, the target prefix shouldn't actually
        # be created.
        HOST="" BUILDTARGETS="llvm-tblgen clang-tblgen llvm-config" $0 $PREFIX/llvmtools
        native=$(find_native_tools)
        if [ -z "$native" ]; then
            echo Unable to find the newly built llvm-tblgen
            exit 1
        fi
    fi

    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_SYSTEM_NAME=Windows"
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_CROSSCOMPILE=1"
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_C_COMPILER=$HOST-gcc"
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_CXX_COMPILER=$HOST-g++"
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_RC_COMPILER=$HOST-windres"

    CMAKEFLAGS="$CMAKEFLAGS -DLLVM_TABLEGEN=$native/llvm-tblgen"
    CMAKEFLAGS="$CMAKEFLAGS -DCLANG_TABLEGEN=$native/clang-tblgen"
    CMAKEFLAGS="$CMAKEFLAGS -DLLVM_CONFIG_PATH=$native/llvm-config"
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
fi

cd llvm
mkdir -p $BUILDDIR
cd $BUILDDIR
cmake \
    ${CMAKE_GENERATOR+-G} "$CMAKE_GENERATOR" \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLVM_ENABLE_ASSERTIONS=$ASSERTS \
    -DLLVM_TARGETS_TO_BUILD="ARM;AArch64;X86" \
    -DLLVM_INSTALL_TOOLCHAIN_ONLY=ON \
    -DLLVM_TOOLCHAIN_TOOLS="llvm-ar;llvm-ranlib;llvm-objdump;llvm-rc;llvm-cvtres;llvm-nm;llvm-strings;llvm-readobj;llvm-dlltool;llvm-pdbutil;llvm-objcopy;llvm-strip" \
    $CMAKEFLAGS \
    ..

: ${BUILDTARGETS:=install/strip}
if [ -n "$NINJA" ]; then
    ninja $BUILDTARGETS
else
    make -j$CORES $BUILDTARGETS
fi
