#!/bin/sh

if [ $# -lt 2 ]; then
    echo $0 image dir
    echo
    echo This extracts \'dir\' from the docker image named \'image\' into the
    echo current directory. NOTE: This removes the existing directory named
    echo \'dir\' first.
    exit 1
fi

image=$1
dir=$2

rm -rf $dir
docker run --rm $image tar -cf - $dir | tar -xvf -
