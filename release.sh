#!/bin/sh
#
# Copyright (c) 2018 Martin Storsjo
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

set -ex

if [ $# -lt 1 ]; then
    echo $0 tag [nativeonly]
    exit 1
fi

TAG=$1

if [ "$2" = "nativeonly" ]; then
    NATIVEONLY=1
fi

time docker build -f Dockerfile . -t mstorsjo/llvm-mingw:latest -t mstorsjo/llvm-mingw:$TAG

DISTRO=ubuntu-18.04-$(uname -m)
docker run --rm mstorsjo/llvm-mingw:latest sh -c "cd /opt && mv llvm-mingw llvm-mingw-$TAG-ucrt-$DISTRO && tar -Jcvf - llvm-mingw-$TAG-ucrt-$DISTRO" > llvm-mingw-$TAG-ucrt-$DISTRO.tar.xz

if [ -n "$NATIVEONLY" ]; then
    exit 0
fi

time docker build -f Dockerfile.dev . -t mstorsjo/llvm-mingw:dev -t mstorsjo/llvm-mingw:dev-$TAG

cleanup() {
    for i in $temp_images; do
        docker rmi --no-prune $i || true
    done
}

trap cleanup EXIT INT TERM

for arch in i686 x86_64 armv7 aarch64; do
    temp=$(uuidgen)
    temp_images="$temp_images $temp"
    time docker build -f Dockerfile.cross --build-arg BASE=mstorsjo/llvm-mingw:dev --build-arg CROSS_ARCH=$arch --build-arg TAG=$TAG-ucrt- -t $temp .
    ./extract-docker.sh $temp /llvm-mingw-$TAG-ucrt-$arch.zip
done

msvcrt_image=llvm-mingw-msvcrt-$(uuidgen)
temp_images="$temp_images $msvcrt_image"
time docker build -f Dockerfile.dev -t $msvcrt_image --build-arg DEFAULT_CRT=msvcrt .

docker run --rm $msvcrt_image sh -c "cd /opt && mv llvm-mingw llvm-mingw-$TAG-msvcrt-$DISTRO && tar -Jcvf - llvm-mingw-$TAG-msvcrt-$DISTRO" > llvm-mingw-$TAG-msvcrt-$DISTRO.tar.xz

for arch in i686 x86_64; do
    temp=$(uuidgen)
    temp_images="$temp_images $temp"
    time docker build -f Dockerfile.cross --build-arg BASE=$msvcrt_image --build-arg CROSS_ARCH=$arch --build-arg TAG=$TAG-msvcrt- -t $temp .
    ./extract-docker.sh $temp /llvm-mingw-$TAG-msvcrt-$arch.zip
done
