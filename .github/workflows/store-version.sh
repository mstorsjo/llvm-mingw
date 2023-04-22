#!/bin/sh

OUT="$1"

if [ -n "$LLVM_VERSION" ]; then
    echo "Nightly $(TZ=UTC date +%Y-%m-%d)" >> $OUT
    for i in LLVM_VERSION MINGW_W64_VERSION PYTHON_VERSION_MINGW; do
        eval val=\"\$$i\"
        if [ -n "$val" ]; then
            echo "$i=$val" >> $OUT
        fi
    done
fi
