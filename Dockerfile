FROM ubuntu:18.04

RUN apt-get update -qq && apt-get install -qqy --no-install-recommends \
    git wget bzip2 file unzip libtool pkg-config cmake build-essential \
    automake yasm gettext autopoint vim python ninja-build \
    ca-certificates curl less && \
    apt-get clean -y && \
    rm -rf /var/lib/apt/lists/*

RUN cd /opt && \
    wget https://github.com/Kitware/CMake/releases/download/v3.16.2/cmake-3.16.2-Linux-x86_64.tar.gz && \
    tar -zxvf cmake-*.tar.gz && \
    rm cmake-*.tar.gz && \
    mv cmake-* cmake
ENV PATH=/opt/cmake/bin:$PATH


RUN git config --global user.name "LLVM MinGW" && \
    git config --global user.email root@localhost

WORKDIR /build

ENV TOOLCHAIN_PREFIX=/opt/llvm-mingw

ARG TOOLCHAIN_ARCHS="i686 x86_64 armv7 aarch64"

ARG DEFAULT_CRT=ucrt

# Build UASM, for building openmp. In the future, llvm-ml should be able
# to handle it, but it doesn't yet.
RUN git clone https://github.com/Terraspace/UASM && \
    cd UASM && \
    git checkout 16a853bd6de807fe2c42569f8375a029684c0f22 && \
    make -f gccLinux64.mak -j$(nproc) && \
    mkdir -p $TOOLCHAIN_PREFIX/bin && \
    cp GccUnixR/uasm $TOOLCHAIN_PREFIX/bin
COPY wrappers/uasm-wrapper.sh $TOOLCHAIN_PREFIX/bin

# Build everything that uses the llvm monorepo. We need to build the mingw runtime before the compiler-rt/libunwind/libcxxabi/libcxx runtimes.
COPY build-llvm.sh strip-llvm.sh install-wrappers.sh build-mingw-w64.sh build-mingw-w64-tools.sh build-compiler-rt.sh build-mingw-w64-libraries.sh build-libcxx.sh build-openmp.sh ./
COPY wrappers/*.sh wrappers/*.c wrappers/*.h ./wrappers/
RUN ./build-llvm.sh $TOOLCHAIN_PREFIX && \
    ./strip-llvm.sh $TOOLCHAIN_PREFIX && \
    ./install-wrappers.sh $TOOLCHAIN_PREFIX && \
    ./build-mingw-w64.sh $TOOLCHAIN_PREFIX --with-default-msvcrt=$DEFAULT_CRT && \
    ./build-mingw-w64-tools.sh $TOOLCHAIN_PREFIX && \
    ./build-compiler-rt.sh $TOOLCHAIN_PREFIX && \
    ./build-mingw-w64-libraries.sh $TOOLCHAIN_PREFIX && \
    ./build-libcxx.sh $TOOLCHAIN_PREFIX && \
    ./build-compiler-rt.sh $TOOLCHAIN_PREFIX --build-sanitizers && \
    ./build-openmp.sh $TOOLCHAIN_PREFIX && \
    rm -rf /build/*

# Build libssp
COPY build-libssp.sh libssp-Makefile ./
RUN ./build-libssp.sh $TOOLCHAIN_PREFIX && \
    rm -rf /build/*

ENV PATH=$TOOLCHAIN_PREFIX/bin:$PATH
