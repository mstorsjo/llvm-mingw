#!/bin/sh

set -e

if [ $# -lt 1 ]; then
    echo $0 dir
    exit 1
fi
PREFIX="$1"
cd "$PREFIX"

cd bin
for i in bugpoint c-index-test clang-* dsymutil git-clang-format llc lli llvm-* obj2yaml opt sancov sanstats scan-build scan-view verify-uselistorder yaml2obj; do
    case $i in
    *.sh)
        ;;
    clang++|clang-*.*|clang-cpp)
        ;;
    clang-*)
        suffix="${i#*-}"
        # Test removing all numbers from the suffix; if it is empty, the suffix
        # was a plain number (as if the original name was clang-7); if it wasn't
        # empty, remove the tool.
        if [ "$(echo $suffix | tr -d '[0-9]')" != "" ]; then
            rm $i
        fi
        ;;
    llvm-ar|llvm-cvtres|llvm-dlltool|llvm-nm|llvm-objdump|llvm-ranlib|llvm-rc|llvm-readobj|llvm-strings)
        ;;
    *)
        if [ -f $i ]; then
            rm $i
        fi
        ;;
    esac
done
cd ..
rm -rf share libexec
cd include
rm -rf clang clang-c lld llvm llvm-c
cd ..
cd lib
rm -rf lib*.a *.so* *.dylib* cmake
cd ..
