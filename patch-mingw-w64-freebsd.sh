#!/usr/bin/env sh
cd mingw-w64
patch -p1 < ../patches/mingw-w64_freebsd.diff
