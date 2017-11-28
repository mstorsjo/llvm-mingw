#!/bin/sh

if [ $# -lt 2 ]; then
    echo $0 image dir
    exit 1
fi

image=$1
dir=$2

rm -rf $dir
docker run --rm $image tar -cf - $dir | tar -xvf -
