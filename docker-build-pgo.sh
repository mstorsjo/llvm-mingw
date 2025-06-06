#!/bin/sh
#
# Copyright (c) 2025 Martin Storsjo
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

time docker build -f Dockerfile.dev . -t llvm-mingw:dev
docker run --rm llvm-mingw:dev sh -c "cd /opt && tar -Jcvf - --format=ustar --numeric-owner --owner=0 --group=0 llvm-mingw" > llvm-mingw-stage1.tar.xz
time docker build -f Dockerfile.profile . -t llvm-mingw:profile --build-arg BASE=llvm-mingw:dev
./extract-docker.sh llvm-mingw:profile profile.profdata
time docker build -f Dockerfile.pgo . -t llvm-mingw:pgo --build-arg BASE=llvm-mingw:dev
docker run --rm llvm-mingw:pgo sh -c "cd /opt && tar -Jcvf - --format=ustar --numeric-owner --owner=0 --group=0 llvm-mingw-pgo" > llvm-mingw-pgo.tar.xz
time docker build -f Dockerfile.cross . -t llvm-mingw:cross --build-arg BASE=llvm-mingw:dev
./extract-docker.sh llvm-mingw:cross /llvm-mingw-x86_64.zip
