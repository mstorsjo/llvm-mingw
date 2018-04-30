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
RUN ./build-all.sh $TOOLCHAIN_PREFIX && \
    ./strip-llvm.sh $TOOLCHAIN_PREFIX && \
    rm -rf /build

ENV PATH=$TOOLCHAIN_PREFIX/bin:$PATH
