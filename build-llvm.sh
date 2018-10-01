#!/bin/sh

set -e

ASSERTS=ON
BUILDDIR=build

while [ $# -gt 0 ]; do
    if [ "$1" = "--disable-asserts" ]; then
        ASSERTS=OFF
        BUILDDIR=build-noasserts
    else
        PREFIX="$1"
    fi
    shift
done
if [ -z "$PREFIX" ]; then
    echo $0 [--disable-asserts] dest
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
    git checkout 5877e4ed63ba21fb57f2c7fb4ed4950288e2a28c
    cd tools/clang
    [ -z "$SYNC" ] || git fetch
    git checkout a866fe7bf7c577b698229106f0ddc2d31b285de8
    cd ../lld
    [ -z "$SYNC" ] || git fetch
    git checkout df3e3050ef26292a8c7d2d16b073588eba28db6c
    cd ../../..
fi

if [ "$(which ninja)" != "" ]; then
    CMAKE_GENERATOR="-G Ninja"
    NINJA=1
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
    ..
if [ -n "$NINJA" ]; then
    ninja install/strip
else
    make -j$CORES install/strip
fi
