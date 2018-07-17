FROM ubuntu:16.04

RUN apt-get update -qq && apt-get install -qqy \
    git wget bzip2 file unzip libtool pkg-config cmake build-essential \
    automake yasm gettext autopoint vim python git-svn ninja-build \
    subversion && \
    apt-get clean -y && \
    rm -rf /var/lib/apt/lists/*


RUN git config --global user.name "LLVM MinGW" && \
    git config --global user.email root@localhost

WORKDIR /build

ARG CORES=4

ENV TOOLCHAIN_PREFIX=/opt/llvm-mingw
ENV TOOLCHAIN_ARCHS="i686 x86_64 armv7 aarch64"

# Build everything and clean up, in one step
COPY *.sh libssp-Makefile ./
COPY wrappers/*.sh ./wrappers/
COPY wrappers/*.c ./wrappers/
RUN ./build-all.sh $TOOLCHAIN_PREFIX && \
    ./strip-llvm.sh $TOOLCHAIN_PREFIX && \
    rm -rf /build

# Cheating: Pull strip and objcopy from the normal binutils package.
RUN apt-get update -qq && \
    apt-get install -qqy binutils-mingw-w64-x86-64 && \
    cp /usr/bin/x86_64-w64-mingw32-strip $TOOLCHAIN_PREFIX/bin/binutils-strip && \
    cp /usr/bin/x86_64-w64-mingw32-objcopy $TOOLCHAIN_PREFIX/bin/binutils-objcopy && \
    apt-get remove -qqy binutils-mingw-w64-x86-64 && \
    apt-get clean -y && \
    rm -rf /var/lib/apt/lists/*

ENV PATH=$TOOLCHAIN_PREFIX/bin:$PATH
