FROM ubuntu:16.04

RUN apt-get update -qq && apt-get install -qqy \
    git wget bzip2 file unzip libtool pkg-config cmake build-essential \
    automake yasm gettext autopoint vim python git-svn ninja-build


RUN git config --global user.name "LLVM MinGW" && \
    git config --global user.email root@localhost

WORKDIR /build/llvm-mingw

ARG CORES=4

ENV TOOLCHAIN_PREFIX=/opt/llvm-mingw

# Build LLVM
COPY build-llvm.sh .
RUN ./build-llvm.sh $TOOLCHAIN_PREFIX

ENV TOOLCHAIN_ARCHS="i686 x86_64 armv7 aarch64"

# Install the usual $TUPLE-clang binaries
COPY wrappers/*.sh ./wrappers/
COPY install-wrappers.sh .
RUN ./install-wrappers.sh $TOOLCHAIN_PREFIX

# Cheating: Pull windres from the normal binutils package.
# llvm-rc isn't fully usable as a replacement for windres yet.
RUN apt-get update -qq && \
    apt-get install -qqy binutils-mingw-w64-x86-64 && \
    cp /usr/bin/x86_64-w64-mingw32-windres $TOOLCHAIN_PREFIX/bin/x86_64-w64-mingw32-windresreal && \
    apt-get remove -qqy binutils-mingw-w64-x86-64

# Build MinGW-w64
COPY build-mingw-w64.sh .
RUN ./build-mingw-w64.sh $TOOLCHAIN_PREFIX

# Build compiler-rt
COPY build-compiler-rt.sh .
RUN ./build-compiler-rt.sh $TOOLCHAIN_PREFIX

# Build C test applications
WORKDIR /build
ENV PATH=$TOOLCHAIN_PREFIX/bin:$PATH

COPY test/*.c ./test/
RUN cd test && \
    for arch in $TOOLCHAIN_ARCHS; do \
        for test in hello hello-tls crt-test; do \
            $arch-w64-mingw32-clang $test.c -o $test-$arch.exe || exit 1; \
        done; \
    done

WORKDIR /build/llvm-mingw

# Build libunwind/libcxxabi/libcxx
COPY build-libcxx.sh merge-archives.sh ./
RUN ./build-libcxx.sh $TOOLCHAIN_PREFIX

WORKDIR /build

# Build C++ test applications
COPY test/*.cpp ./test/
RUN cd test && \
    for arch in $TOOLCHAIN_ARCHS; do \
        for test in hello-cpp hello-exception; do \
            $arch-w64-mingw32-clang++ $test.cpp -o $test-$arch.exe || exit 1; \
        done; \
    done
