#!/bin/sh

DIR="$(cd "$(dirname "$0")" && pwd)"
export PATH="$DIR":"$PATH"

if [ "$1" = "-f" ]; then
    # libtool can try to run objdump -f and wants to see certain strings in
    # the output, to accept it being a windows (import) library
    llvm-readobj $2 | while read -r line; do
        case $line in
        File:*)
            file=$(echo $line | awk '{print $2}')
            ;;
        Format:*)
            format=$(echo $line | awk '{print $2}')
            case $format in
            COFF-i386)
                format=pe-i386
                ;;
            COFF-x86-64)
                format=pe-x86-64
                ;;
            COFF-ARM*)
                # This is wrong; modern COFF armv7 isn't pe-arm-wince, and
                # arm64 definitely isn't, but libtool wants to see this
                # string (or some of the others) in order to accept it.
                format=pe-arm-wince
                ;;
            esac
            echo $file: file format $format
            ;;
        esac
    done
else
    llvm-objdump "$@"
fi
