#!/bin/sh

set -e

if [ $# -lt 1 ]; then
    echo $0 dir
    exit 1
fi
PREFIX="$1"
cd "$PREFIX"

cd bin
for i in bugpoint c-index-test clang-* git-clang-format llc lli llvm-* obj2yaml opt sancov sanstats scan-build scan-view verify-uselistorder yaml2obj; do
    case $i in
    clang++|clang-*.*|clang-cpp)
        ;;
    *.sh)
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

if false; then
cat <<EOF > bin/llvm-config
#!/bin/sh
ROOT="$PREFIX"
while [ \$# -gt 0 ]; do
    case \$1 in
    --obj-root|--prefix)
        echo \$ROOT
        ;;
    --bindir)
        echo \$ROOT/bin
        ;;
    --includedir)
        echo \$ROOT/include
        ;;
    --libdir)
        echo \$ROOT/lib
        ;;
    --src-root)
        echo \$ROOT/src
        ;;
    --cmakedir)
        echo \$ROOT/lib/cmake/llvm
        ;;
    esac
    shift
done
EOF
chmod a+x bin/llvm-config
mkdir -p lib/cmake/llvm
touch lib/cmake/llvm/LLVMConfig.cmake
fi
