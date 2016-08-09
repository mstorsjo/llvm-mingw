FROM ubuntu:16.04

MAINTAINER Hugo Beauzée-Luyssen <hugo@beauzee.fr>

#FIXME: Remove vim once debuging is complete
RUN apt-get update -qq && apt-get install -qqy \
    git wget bzip2 file libwine-development-dev unzip libtool pkg-config cmake \
    build-essential automake texinfo ragel yasm p7zip-full gettext autopoint \
    vim python


RUN git config --global user.name "VideoLAN Buildbot" && \
    git config --global user.email buildbot@videolan.org

WORKDIR /build

COPY patches/ /build/patches

RUN git clone -b release_39 https://github.com/llvm-mirror/llvm.git --depth=1
RUN cd llvm/tools && \
    git clone -b release_39 --depth=1 https://github.com/llvm-mirror/clang.git && \
    git clone --depth=1 -b release_39 https://github.com/llvm-mirror/lld.git --depth=1

#RUN cd llvm/projects && \
#    git clone -b release_39 --depth=1 https://github.com/llvm-mirror/libcxx.git && \
#    git clone -b release_39 --depth=1 https://github.com/llvm-mirror/libcxxabi.git && \
#    git clone https://github.com/llvm-mirror/libunwind.git -b release_39 --depth=1

RUN cd llvm && \
    git am /build/patches/llvm-*.patch

RUN cd llvm/tools/clang && \
    git am /build/patches/clang-*.patch

RUN cd llvm/tools/lld && \
    git am /build/patches/lld-*.patch

#RUN cd llvm/projects/libcxx && \
#    git am /build/patches/libcxx-*.patch

RUN git clone --depth=1 git://git.code.sf.net/p/mingw-w64/mingw-w64
RUN cd mingw-w64 && \
    git am /build/patches/mingw-*.patch

RUN git clone -b release_39 --depth=1 https://github.com/llvm-mirror/compiler-rt.git

RUN mkdir /build/prefix

# Build LLVM
RUN cd llvm && mkdir build && cd build && cmake \
    -DCMAKE_INSTALL_PREFIX="/build/prefix" \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLVM_TARGETS_TO_BUILD="ARM;CppBackend;X86" \
    -DLLVM_ENABLE_ASSERTIONS=OFF \
    -DLLVM_ENABLE_EH=ON \
    -DLLVM_ENABLE_THREADS=ON \
    -DLLVM_ENABLE_RTTI=ON \
    -DLLVM_ENABLE_FFI=OFF \
    -DLLVM_ENABLE_SPHINX=OFF \
    -DCMAKE_CXX_FLAGS="-D_GNU_SOURCE -D_LIBCPP_HAS_NO_CONSTEXPR" \
    ../ && \
    make -j4 && \
    make install

#FIXME: Move this UP!
ENV TOOLCHAIN_PREFIX=/build/prefix
ENV TARGET_TUPLE=armv7-w64-mingw32
ENV MINGW_PREFIX=$TOOLCHAIN_PREFIX/$TARGET_TUPLE
ENV PATH=$TOOLCHAIN_PREFIX/bin:$PATH

RUN mkdir $MINGW_PREFIX
RUN ln -s $MINGW_PREFIX $TOOLCHAIN_PREFIX/mingw

RUN cd mingw-w64/mingw-w64-tools/genlib && \
    mkdir build && cd build && \
    ../configure --prefix=$TOOLCHAIN_PREFIX && \
    make -j4 && \
    make install

RUN cd mingw-w64/mingw-w64-headers && mkdir build && cd build && \
    ../configure --host=$TARGET_TUPLE --prefix=$MINGW_PREFIX \
        --enable-secure-api && \
    make install

# Install the usual $TUPLE-clang binary
COPY wrappers/* $TOOLCHAIN_PREFIX/bin/

ENV CC=armv7-w64-mingw32-clang
ENV CXX=armv7-w64-mingw32-clang++
ENV AR=llvm-ar 
ENV RANLIB=llvm-ranlib 
ENV LD=lld
ENV AS=llvm-as
ENV NM=llvm-nm

# Build mingw with our freshly built cross compiler
RUN cd mingw-w64/mingw-w64-crt && \
    autoreconf -vif && \
    mkdir build && cd build && \
    ../configure --host=$TARGET_TUPLE --prefix=$MINGW_PREFIX \
        --disable-lib32 --disable-lib64 --enable-libarm32 \
        --with-genlib && \
    make -j4 && \
    make install

RUN cp /build/mingw-w64/mingw-w64-libraries/winpthreads/include/* $MINGW_PREFIX/include/

#Work around upstream issue with capital W windows.h
RUN ln -s /build/prefix/armv7-w64-mingw32/include/windows.h /build/prefix/armv7-w64-mingw32/include/Windows.h

# Manually build compiler-rt as a standalone project
RUN cd compiler-rt && \
    make clang_mingw-builtins-arm

RUN mkdir -p /build/prefix/lib/clang/3.9.0/lib/windows && \
    cp /build/compiler-rt/clang_mingw/builtins-arm/libcompiler_rt.a /build/prefix/lib/clang/3.9.0/lib/windows/libclang_rt.builtins-arm.a

RUN cd mingw-w64/mingw-w64-libraries && cd winstorecompat && \
    autoreconf -vif && \
    mkdir build && cd build && \
    ../configure --host=$TARGET_TUPLE --prefix=$MINGW_PREFIX && make && make install

RUN cd /build/mingw-w64/mingw-w64-tools/widl && \
    mkdir build && cd build && \
    CC=gcc \
    ../configure --prefix=$TOOLCHAIN_PREFIX --target=$TARGET_TUPLE && \
    make -j4 && \
    make install 

#RUN git clone -b release_39 --depth=1 https://github.com/llvm-mirror/libcxx.git && \
#    git clone -b release_39 --depth=1 https://github.com/llvm-mirror/libcxxabi.git && \
#    git clone -b release_39 --depth=1 https://github.com/llvm-mirror/libunwind.git

#RUN cd libcxx && \
#    git am /build/patches/libcxx-*.patch

#RUN cd libunwind && \
#    git am /build/patches/libunwind-*.patch

#RUN cd libunwind && mkdir build && cd build && \
#    CXXFLAGS="-nodefaultlibs -D_LIBUNWIND_IS_BAREMETAL" \
#    LDFLAGS="/build/prefix/armv7-w64-mingw32/lib/crt2.o /build/prefix/armv7-w64-mingw32/lib/crtbegin.o -lmingw32 /build/prefix/bin/../lib/clang/3.8.1/lib/windows/libclang_rt.builtins-arm.a -lmoldname -lmingwex -lmsvcrt -ladvapi32 -lshell32 -luser32 -lkernel32 /build/prefix/armv7-w64-mingw32/lib/crtend.o" \
#    cmake \
#        -DCMAKE_CXX_COMPILER_WORKS=TRUE \
#        -DLLVM_ENABLE_LIBCXX=TRUE \
#        -DCMAKE_BUILD_TYPE=Release \
#        -DLIBUNWIND_ENABLE_SHARED=OFF \
#        ..

#RUN cd libunwind/build && make -j4
#RUN cd libunwind/build && make install

#RUN cd libcxx && mkdir build && cd build && \
#    CXXFLAGS="-nodefaultlibs -D_GNU_SOURCE -D_LIBCPP_HAS_NO_CONSTEXPR" \
#    LDFLAGS="/build/prefix/armv7-w64-mingw32/lib/crt2.o /build/prefix/armv7-w64-mingw32/lib/crtbegin.o -lmingw32 /build/prefix/bin/../lib/clang/3.8.1/lib/windows/libclang_rt.builtins-arm.a -lmoldname -lmingwex -lmsvcrt -ladvapi32 -lshell32 -luser32 -lkernel32 /build/prefix/armv7-w64-mingw32/lib/crtend.o" \
#    cmake \
#        -DCMAKE_CXX_COMPILER_WORKS=TRUE \
#        -DLIBCXX_ENABLE_SHARED=OFF \
#        -DCMAKE_BUILD_TYPE=Release \
#        -DCMAKE_INSTALL_PREFIX="/build/prefix" \
#        .. && \
#    make -j8 && \
#    make install

RUN mkdir gaspp && cd gaspp && \
    wget -q https://raw.githubusercontent.com/libav/gas-preprocessor/master/gas-preprocessor.pl && \
    chmod +x gas-preprocessor.pl

ENV PATH=/build/gaspp:$PATH

ENV AS="gas-preprocessor.pl ${CC}"
ENV ASCPP="gas-preprocessor.pl ${CC}"
ENV CCAS="gas-preprocessor.pl ${CC}"
ENV LDFLAGS="-lmsvcr120_app ${LDFLAGS}"

