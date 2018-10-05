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
    git checkout a978525b6415baf1f6a3f49b2cc8b50167f06e60
    cd tools/clang
    [ -z "$SYNC" ] || git fetch
    git checkout 122fb01a0d3afdb020866c719896161a1b829e03
    cd ../lld
    [ -z "$SYNC" ] || git fetch
    git checkout d0c1d02fc3bb851b22f4e5396c9c5afa91842c7b
    cd ../../..
fi

if [ -n "$(which ninja)" ]; then
    CMAKE_GENERATOR="-G Ninja"
    NINJA=1
fi

if [ -n "$HOST" ]; then
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_SYSTEM_NAME=Windows"
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_CROSSCOMPILE=1"
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_C_COMPILER=$HOST-gcc"
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_CXX_COMPILER=$HOST-g++"
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_RC_COMPILER=$HOST-windres"
    if [ -d llvm/build/bin ]; then
        native=$(pwd)/llvm/build/bin
    elif [ -d llvm/build-asserts/bin ]; then
        native=$(pwd)/llvm/build-asserts/bin
    elif [ -d llvm/build-noasserts/bin ]; then
        native=$(pwd)/llvm/build-noasserts/bin
    else
        native=$(dirname $(which llvm-tblgen))
    fi
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
    $CMAKE_GENERATOR \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLVM_ENABLE_ASSERTIONS=$ASSERTS \
    -DLLVM_TARGETS_TO_BUILD="ARM;AArch64;X86" \
    -DLLVM_INSTALL_TOOLCHAIN_ONLY=ON \
    -DLLVM_TOOLCHAIN_TOOLS="llvm-ar;llvm-ranlib;llvm-objdump;llvm-rc;llvm-cvtres;llvm-nm;llvm-strings;llvm-readobj;llvm-dlltool;llvm-pdbutil" \
    $CMAKEFLAGS \
    ..
if [ -n "$NINJA" ]; then
    ninja install/strip
else
    make -j$CORES install/strip
fi
