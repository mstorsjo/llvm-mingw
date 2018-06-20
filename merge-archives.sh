#!/bin/sh

set -e

if [ $# -lt 2 ]; then
    echo $0 lib add1 [add2...]
    exit 1
fi

: ${AR:=llvm-ar}
: ${RANLIB:=llvm-ranlib}

SCRIPT=merge.mri
OUT=tmp.a
TARGET=$1

rm -f $SCRIPT

echo "CREATE $OUT" >> $SCRIPT
case $(uname) in
MINGW*)
    while [ $# -gt 0 ]; do
        echo "ADDLIB $(cygpath -w $1)" >> $SCRIPT
        shift
    done
    ;;
*)
    while [ $# -gt 0 ]; do
        echo "ADDLIB $1" >> $SCRIPT
        shift
    done
    ;;
esac
echo "SAVE" >> $SCRIPT
echo "END" >> $SCRIPT
$AR -M < $SCRIPT
rm -f $SCRIPT
$RANLIB $OUT
mv $OUT $TARGET
