FROM ubuntu:24.04

RUN apt-get update -qq && \
    DEBIAN_FRONTEND="noninteractive" apt-get install -qqy --no-install-recommends \
    git wget bzip2 file unzip libtool pkg-config cmake build-essential \
    automake nasm gettext autopoint vim-tiny python3 \
    ninja-build ca-certificates curl less zip && \
    apt-get clean -y && \
    rm -rf /var/lib/apt/lists/*


RUN git config --global user.name "LLVM MinGW" && \
    git config --global user.email root@localhost

WORKDIR /build

ENV TOOLCHAIN_PREFIX=/opt/llvm-mingw

ARG TOOLCHAIN_ARCHS="i686 x86_64 armv7 aarch64"

ARG DEFAULT_CRT=ucrt

ARG CFGUARD_ARGS=--enable-cfguard

COPY build-all.sh build-llvm.sh build-lldb-mi.sh strip-llvm.sh install-wrappers.sh build-mingw-w64.sh build-mingw-w64-tools.sh build-compiler-rt.sh build-libcxx.sh build-mingw-w64-libraries.sh build-openmp.sh ./
COPY wrappers/*.sh wrappers/*.c wrappers/*.h wrappers/*.cfg ./wrappers/
RUN ./build-all.sh $TOOLCHAIN_PREFIX --with-default-msvcrt=$DEFAULT_CRT $CFGUARD_ARGS && \
    rm -rf /build/*

ENV PATH=$TOOLCHAIN_PREFIX/bin:$PATH
