#!/bin/sh
#
# Copyright (c) 2024 Martin Storsjo
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
    echo $0 prefix
    exit 1
fi
PREFIX="$1"
PREFIX="$(cd "$PREFIX" && pwd)"
export PATH=$PREFIX/bin:$PATH

: ${ARCHS:=${TOOLCHAIN_ARCHS-i686 x86_64 armv7 aarch64}}

for arch in $ARCHS; do
    # TODO: This should ideally use "$CXX -print-file-name=libc++.modules.json", then parse the json to find the relevant cppm file and include directory.
    $arch-w64-mingw32-clang++ -I$PREFIX/share/libc++/v1 -std=gnu++23 -Wno-reserved-module-identifier -x c++-module -fmodule-output=std.pcm -o std.cppm.obj -c $PREFIX/share/libc++/v1/std.cppm
    $arch-w64-mingw32-clang++ -I$PREFIX/share/libc++/v1 -std=gnu++23 -Wno-reserved-module-identifier -x c++-module -fmodule-output=std.compat.pcm -fmodule-file=std=std.pcm -o std.compat.cppm.obj -c $PREFIX/share/libc++/v1/std.compat.cppm
    $arch-w64-mingw32-clang-scan-deps -format=p1689 -- $arch-w64-mingw32-clang++ -std=c++23 -c test/test-scan-deps.cpp -DEXPECT_$arch
done

if [ -n "$NATIVE" ]; then
    # Test the unprefixed clang-scan-deps wrapper.
    clang-scan-deps -format=p1689 -- clang++ -std=c++23 -c test/test-scan-deps.cpp -DEXPECT_$(clang++ -dumpmachine | sed 's/-.*//')
fi
