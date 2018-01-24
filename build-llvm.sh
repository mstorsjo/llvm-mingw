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
    git checkout 34715e9f75ecf832ff06f7e979653a52ba4a5b6c
    cd tools/clang
    [ -z "$SYNC" ] || git fetch
    git checkout 903b385001790aadf3c1d2024a5b63267379a65a
    cd ../lld
    [ -z "$SYNC" ] || git fetch
    git checkout 54662472e3598dac2165d090a05c8d4db62fcafb
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
    ninja install
else
    make -j$CORES install
fi
