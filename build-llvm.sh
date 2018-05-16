#!/bin/sh

set -e

if [ $# -lt 1 ]; then
    echo $0 dest
    exit 1
fi
PREFIX="$1"

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
    git checkout 27b0d8a7623cfc7f194675352362fc4a16d2273f
    cd tools/clang
    [ -z "$SYNC" ] || git fetch
    git checkout 0d65696b0e430a4078829ffea218c0fb04421dd5
    cd ../lld
    [ -z "$SYNC" ] || git fetch
    git checkout f86124c33d0a97cfd636a050361a27c8b9459c2b
    cd ../../..
fi

if [ "$(which ninja)" != "" ]; then
    CMAKE_GENERATOR="-G Ninja"
    NINJA=1
fi

cd llvm
mkdir -p build
cd build
cmake \
    $CMAKE_GENERATOR \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLVM_ENABLE_ASSERTIONS=ON \
    -DLLVM_TARGETS_TO_BUILD="ARM;AArch64;X86" \
    ..
if [ -n "$NINJA" ]; then
    ninja install/strip
else
    make -j$CORES install/strip
fi
