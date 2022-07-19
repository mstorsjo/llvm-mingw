FROM ubuntu:18.04

RUN apt-get update -qq && apt-get install -qqy --no-install-recommends \
    git wget bzip2 file unzip libtool pkg-config cmake build-essential \
    automake yasm gettext autopoint vim-tiny python3 python3-distutils \
    ninja-build ca-certificates curl less zip && \
    apt-get clean -y && \
    rm -rf /var/lib/apt/lists/*

# Manually install a newer version of CMake; this is needed since building
# LLVM requires CMake 3.13.4, while Ubuntu 18.04 ships with 3.10.2. If
# updating to a newer distribution, this can be dropped.
RUN cd /opt && \
    wget https://github.com/Kitware/CMake/releases/download/v3.20.1/cmake-3.20.1-Linux-$(uname -m).tar.gz && \
    tar -zxvf cmake-*.tar.gz && \
    rm cmake-*.tar.gz && \
    mv cmake-* cmake
ENV PATH=/opt/cmake/bin:$PATH

# Install a newer version of Git; the version of Git in Ubuntu 18.04 is
# said to have issues with submodules, see e.g.
# https://github.com/mstorsjo/llvm-mingw/pull/210#issuecomment-870104971 and
# https://github.com/mstorsjo/llvm-mingw/pull/210#issuecomment-873486503.
# This isn't needed for building LLVM itself, but makes the built Docker
# image more useful for use as image for building other projects. If updating
# to a newer distribution, this can be dropped.
RUN apt-get update -qq && \
    apt-get install -qqy --no-install-recommends software-properties-common && \
    add-apt-repository ppa:git-core/ppa && \
    apt-get update -qq && \
    apt-get upgrade -qqy git && \
    apt-get clean -y && \
    rm -rf /var/lib/apt/lists/*


RUN git config --global user.name "LLVM MinGW" && \
    git config --global user.email root@localhost

WORKDIR /build

ENV TOOLCHAIN_PREFIX=/opt/llvm-mingw

ARG TOOLCHAIN_ARCHS="i686 x86_64 armv7 aarch64"

ARG DEFAULT_CRT=ucrt

# Build everything that uses the llvm monorepo. We need to build the mingw runtime before the compiler-rt/libunwind/libcxxabi/libcxx runtimes.
COPY build-llvm.sh build-lldb-mi.sh strip-llvm.sh install-wrappers.sh build-mingw-w64.sh build-mingw-w64-tools.sh build-compiler-rt.sh build-libcxx.sh build-mingw-w64-libraries.sh build-openmp.sh build-flang-runtime.sh ./
COPY wrappers/*.sh wrappers/*.c wrappers/*.h ./wrappers/
RUN ./build-llvm.sh $TOOLCHAIN_PREFIX && \
    ./build-lldb-mi.sh $TOOLCHAIN_PREFIX && \
    ./strip-llvm.sh $TOOLCHAIN_PREFIX && \
    ./install-wrappers.sh $TOOLCHAIN_PREFIX && \
    ./build-mingw-w64.sh $TOOLCHAIN_PREFIX --with-default-msvcrt=$DEFAULT_CRT && \
    ./build-mingw-w64-tools.sh $TOOLCHAIN_PREFIX && \
    ./build-compiler-rt.sh $TOOLCHAIN_PREFIX && \
    ./build-libcxx.sh $TOOLCHAIN_PREFIX && \
    ./build-mingw-w64-libraries.sh $TOOLCHAIN_PREFIX && \
    ./build-compiler-rt.sh $TOOLCHAIN_PREFIX --build-sanitizers && \
    ./build-openmp.sh $TOOLCHAIN_PREFIX && \
    ./build-flang-runtime.sh $TOOLCHAIN_PREFIX && \
    rm -rf /build/*

# Build libssp
COPY build-libssp.sh libssp-Makefile ./
RUN ./build-libssp.sh $TOOLCHAIN_PREFIX && \
    rm -rf /build/*

ENV PATH=$TOOLCHAIN_PREFIX/bin:$PATH
