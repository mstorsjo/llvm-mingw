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
    elif [ "$1" = "--full-llvm" ]; then
        FULL_LLVM=1
    else
        PREFIX="$1"
    fi
    shift
done
if [ -z "$PREFIX" ]; then
    echo $0 [--enable-asserts] [--full-llvm] dest
    exit 1
fi

mkdir -p "$PREFIX"
PREFIX="$(cd "$PREFIX" && pwd)"

: ${CORES:=$(nproc 2>/dev/null)}
: ${CORES:=$(sysctl -n hw.ncpu 2>/dev/null)}
: ${CORES:=4}

if [ ! -d llvm ]; then
    # When cloning master and checking out a pinned old hash, we can't use --depth=1.
    git clone -b master https://github.com/llvm-mirror/llvm.git
    cd llvm/tools
    git clone -b master https://github.com/llvm-mirror/clang.git
    git clone -b master https://github.com/llvm-mirror/lld.git
    cd ..
    set +e
    # Do the git-svn rebase to populate git-svn information, to make
    # "clang --version" produce SVN based version numbers.
    # This is optional - don't error out here if git-svn is unavailable.
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
    set -e
    CHECKOUT=1
fi

if [ -n "$SYNC" ] || [ -n "$CHECKOUT" ]; then
    cd llvm
    [ -z "$SYNC" ] || git fetch
    git checkout 6bbf836d66c1c71287773dc2201ab1b416050d80
    cd tools/clang
    [ -z "$SYNC" ] || git fetch
    git checkout 39af588aaa995c092806bbb467680649b858d82b
    cd ../lld
    [ -z "$SYNC" ] || git fetch
    git checkout fa3678e53a6173fa86edc6c3d60b86d9fa11f0fd
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

    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_SYSTEM_NAME=Windows"
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_CROSSCOMPILING=TRUE"
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_C_COMPILER=$HOST-gcc"
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_CXX_COMPILER=$HOST-g++"
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_RC_COMPILER=$HOST-windres"
    CMAKEFLAGS="$CMAKEFLAGS -DCROSS_TOOLCHAIN_FLAGS_NATIVE="

    native=$(find_native_tools)
    if [ -n "$native" ]; then
        CMAKEFLAGS="$CMAKEFLAGS -DLLVM_TABLEGEN=$native/llvm-tblgen"
        CMAKEFLAGS="$CMAKEFLAGS -DCLANG_TABLEGEN=$native/clang-tblgen"
        CMAKEFLAGS="$CMAKEFLAGS -DLLVM_CONFIG_PATH=$native/llvm-config"
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
fi

TOOLCHAIN_ONLY=ON
if [ -n "$FULL_LLVM" ]; then
    TOOLCHAIN_ONLY=OFF
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
    -DLLVM_INSTALL_TOOLCHAIN_ONLY=$TOOLCHAIN_ONLY \
    -DLLVM_TOOLCHAIN_TOOLS="llvm-ar;llvm-ranlib;llvm-objdump;llvm-rc;llvm-cvtres;llvm-nm;llvm-strings;llvm-readobj;llvm-dlltool;llvm-pdbutil;llvm-objcopy;llvm-strip;llvm-cov;llvm-profdata" \
    $CMAKEFLAGS \
    ..

if [ -n "$NINJA" ]; then
    ninja -j$CORES install/strip
else
    make -j$CORES install/strip
fi
