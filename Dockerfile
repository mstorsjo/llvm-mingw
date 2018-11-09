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

ENV TOOLCHAIN_PREFIX=/opt/llvm-mingw

# Build and strip the LLVM installation
COPY build-llvm.sh strip-llvm.sh ./
RUN ./build-llvm.sh $TOOLCHAIN_PREFIX && \
    ./strip-llvm.sh $TOOLCHAIN_PREFIX && \
    rm -rf /build/*

ARG TOOLCHAIN_ARCHS="i686 x86_64 armv7 aarch64"

# Install the usual $TUPLE-clang binaries
COPY wrappers/*.sh wrappers/*.c ./wrappers/
COPY install-wrappers.sh ./
RUN ./install-wrappers.sh $TOOLCHAIN_PREFIX && \
    rm -rf /build/*

# Build MinGW-w64, compiler-rt and mingw-w64's extra libraries
COPY build-mingw-w64.sh build-compiler-rt.sh build-mingw-w64-libraries.sh ./
RUN ./build-mingw-w64.sh $TOOLCHAIN_PREFIX && \
    ./build-compiler-rt.sh $TOOLCHAIN_PREFIX && \
    ./build-mingw-w64-libraries.sh $TOOLCHAIN_PREFIX && \
    rm -rf /build/*

# Build libunwind/libcxxabi/libcxx
COPY build-libcxx.sh merge-archives.sh ./
RUN ./build-libcxx.sh $TOOLCHAIN_PREFIX && \
    rm -rf /build/*

# Build sanitizers
COPY build-compiler-rt.sh ./
RUN ./build-compiler-rt.sh $TOOLCHAIN_PREFIX --build-sanitizers && \
    rm -rf /build/*

# Build libssp
COPY build-libssp.sh libssp-Makefile ./
RUN ./build-libssp.sh $TOOLCHAIN_PREFIX && \
    rm -rf /build/*

# Cheating: Pull strip and objcopy from the normal binutils package.
RUN apt-get update -qq && \
    apt-get install -qqy binutils-mingw-w64-x86-64 && \
    cp /usr/bin/x86_64-w64-mingw32-strip $TOOLCHAIN_PREFIX/bin/binutils-strip && \
    cp /usr/bin/x86_64-w64-mingw32-objcopy $TOOLCHAIN_PREFIX/bin/binutils-objcopy && \
    apt-get remove -qqy binutils-mingw-w64-x86-64 && \
    apt-get clean -y && \
    rm -rf /var/lib/apt/lists/*

ENV PATH=$TOOLCHAIN_PREFIX/bin:$PATH
