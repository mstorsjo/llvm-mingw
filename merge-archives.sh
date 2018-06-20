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
while [ $# -gt 0 ]; do
    case $(uname) in
    MINGW*)
        echo "ADDLIB $(cygpath -w $1)" >> $SCRIPT
        ;;
    *)
        echo "ADDLIB $1" >> $SCRIPT
        ;;
    esac
    shift
done
echo "SAVE" >> $SCRIPT
echo "END" >> $SCRIPT
$AR -M < $SCRIPT
rm -f $SCRIPT
$RANLIB $OUT
mv $OUT $TARGET
