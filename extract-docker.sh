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

rm -rf $(echo $dir | sed 's,^/,,')
docker run --rm $image tar -cf - $dir | tar -xvf -
