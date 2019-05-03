#!/bin/sh

set -ex

if [ $# -lt 1 ]; then
    echo $0 tag
    exit 1
fi

TAG=$1

time docker build -f Dockerfile . -t mstorsjo/llvm-mingw:latest -t mstorsjo/llvm-mingw:$TAG
time docker build -f Dockerfile.dev . -t mstorsjo/llvm-mingw:dev -t mstorsjo/llvm-mingw:dev-$TAG

DISTRO=ubuntu-16.04
docker run --rm mstorsjo/llvm-mingw:latest sh -c "cd /opt && mv llvm-mingw llvm-mingw-$TAG-$DISTRO && tar -Jcvf - llvm-mingw-$TAG-$DISTRO" > llvm-mingw-$TAG-$DISTRO.tar.xz

cleanup() {
    for i in $temp_images; do
        docker rmi --no-prune $i || true
    done
}

trap cleanup EXIT INT TERM

for arch in i686 x86_64 armv7 aarch64; do
    temp=$(uuidgen)
    temp_images="$temp_images $temp"
    time docker build -f Dockerfile.cross --build-arg BASE=mstorsjo/llvm-mingw:dev --build-arg CROSS_ARCH=$arch --build-arg TAG=$TAG- -t $temp .
    ./extract-docker.sh $temp /llvm-mingw-$TAG-$arch.zip
done
