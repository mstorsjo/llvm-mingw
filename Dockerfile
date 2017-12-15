FROM ubuntu:16.04

#FIXME: Remove vim once debuging is complete
# git-svn is only used to get sensible version numbers in clang version printouts
RUN apt-get update -qq && apt-get install -qqy \
    git wget bzip2 file libwine-development-dev unzip libtool pkg-config cmake \
    build-essential automake texinfo ragel yasm p7zip-full gettext autopoint \
    vim python git-svn


RUN git config --global user.name "LLVM MinGW" && \
    git config --global user.email root@localhost

WORKDIR /build

# When cloning master and checking out a pinned old hash, we can't use --depth=1.
# Do the git-svn rebase to populate git-svn information, to make
# "clang --version" produce SVN based version numbers.
RUN git clone -b master https://github.com/llvm-mirror/llvm.git && \
    cd llvm/tools && \
    git clone -b master https://github.com/llvm-mirror/clang.git && \
    git clone -b master https://github.com/llvm-mirror/lld.git && \
    cd .. && \
    git svn init https://llvm.org/svn/llvm-project/llvm/trunk && \
    git config svn-remote.svn.fetch :refs/remotes/origin/master && \
    git svn rebase -l && \
    git checkout c8f103e52b297f3e3e0ed1756e11373c68af3566 && \
    cd tools/clang && \
    git svn init https://llvm.org/svn/llvm-project/cfe/trunk && \
    git config svn-remote.svn.fetch :refs/remotes/origin/master && \
    git svn rebase -l && \
    git checkout fdd60aee9c0ea40fa0423d6e43821f53d07961d5 && \
    cd ../lld && \
    git svn init https://llvm.org/svn/llvm-project/lld/trunk && \
    git config svn-remote.svn.fetch :refs/remotes/origin/master && \
    git svn rebase -l && \
    git checkout f4208caae12f685c06657aa6e2b9b1eda4adcdb4


# Build LLVM
RUN cd llvm && mkdir build && cd build && cmake \
    -DCMAKE_INSTALL_PREFIX="/build/prefix" \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLVM_ENABLE_ASSERTIONS=ON \
    -DLLVM_TARGETS_TO_BUILD="ARM;AArch64;X86" \
    ../ && \
    make -j4 && \
    make install

RUN git clone git://git.code.sf.net/p/mingw-w64/mingw-w64 && \
    cd mingw-w64 && \
    git checkout 578e5837be72de29994d5931bd22541696de4ba5


ENV TOOLCHAIN_PREFIX=/build/prefix
ENV PATH=$TOOLCHAIN_PREFIX/bin:$PATH
ENV TOOLCHAIN_ARCHS="i686 x86_64 armv7 aarch64"

RUN cd mingw-w64/mingw-w64-headers && \
    for arch in $TOOLCHAIN_ARCHS; do \
        mkdir build-$arch && cd build-$arch && \
        ../configure --host=$arch-w64-mingw32 --prefix=$TOOLCHAIN_PREFIX/$arch-w64-mingw32 \
            --enable-secure-api --with-default-win32-winnt=0x600 && \
        make install && \
        cd .. || exit 1; \
    done

# Install the usual $TUPLE-clang binaries
COPY wrappers/clang-target-wrapper /build/prefix/bin
RUN cd $TOOLCHAIN_PREFIX/bin && \
    for arch in $TOOLCHAIN_ARCHS; do \
        for exec in clang clang++; do \
            ln -s clang-target-wrapper $arch-w64-mingw32-$exec; \
        done; \
    done

# Build mingw with our freshly built cross compiler
RUN cd mingw-w64/mingw-w64-crt && \
    for arch in $TOOLCHAIN_ARCHS; do \
        mkdir build-$arch && cd build-$arch && \
        case $arch in \
        armv7) \
            FLAGS="--disable-lib32 --disable-lib64 --enable-libarm32" \
            ;; \
        aarch64) \
            FLAGS="--disable-lib32 --disable-lib64 --enable-libarm64" \
            ;; \
        i686) \
            FLAGS="--enable-lib32 --disable-lib64" \
            ;; \
        x86_64) \
            FLAGS="--disable-lib32 --enable-lib64" \
            ;; \
        esac && \
        CC=$arch-w64-mingw32-clang \
        AR=llvm-ar RANLIB=llvm-ranlib DLLTOOL=llvm-dlltool ../configure --host=$arch-w64-mingw32 --prefix=$TOOLCHAIN_PREFIX/$arch-w64-mingw32 $FLAGS && \
        make -j4 && make install && \
        cd .. || exit 1; \
    done

#RUN cp /build/mingw-w64/mingw-w64-libraries/winpthreads/include/* $MINGW_PREFIX/include/

RUN git clone -b master https://github.com/llvm-mirror/compiler-rt.git && \
    cd compiler-rt && \
    git checkout 1d871d6cd3fed01cd50dd63e743bd2ea6e65eab6

# Add a symlink for i386 -> i686; we normally name the toolchain
# i686-w64-mingw32, but due to the compiler-rt cmake peculiarities, we
# need to refer to it as i386 at this stage.
RUN cd $TOOLCHAIN_PREFIX && ln -s i686-w64-mingw32 i386-w64-mingw32

# Manually build compiler-rt as a standalone project
RUN cd compiler-rt && \
    for arch in $TOOLCHAIN_ARCHS; do \
        buildarchname=$arch && \
        libarchname=$arch && \
        case $arch in \
        armv7) \
            libarchname=arm \
            ;; \
        i686) \
            buildarchname=i386 \
            libarchname=i386 \
            ;; \
        esac && \
        mkdir build-$arch && cd build-$arch && cmake \
            -DCMAKE_C_COMPILER=$arch-w64-mingw32-clang \
            -DCMAKE_SYSTEM_NAME=Windows \
            -DCMAKE_AR=$TOOLCHAIN_PREFIX/bin/llvm-ar \
            -DCMAKE_RANLIB=$TOOLCHAIN_PREFIX/bin/llvm-ranlib \
            -DCMAKE_C_COMPILER_WORKS=1 \
            -DCMAKE_C_COMPILER_TARGET=$buildarchname-windows-gnu \
            -DCOMPILER_RT_DEFAULT_TARGET_ONLY=TRUE \
            ../lib/builtins && \
        make -j4 && \
        mkdir -p $TOOLCHAIN_PREFIX/lib/clang/6.0.0/lib/windows && \
        cp lib/windows/libclang_rt.builtins-$buildarchname.a $TOOLCHAIN_PREFIX/lib/clang/6.0.0/lib/windows/libclang_rt.builtins-$libarchname.a && \
        cd .. || exit 1; \
    done

#RUN cd mingw-w64/mingw-w64-libraries && cd winstorecompat && \
#    autoreconf -vif && \
#    mkdir build && cd build && \
#    ../configure --host=$TARGET_TUPLE --prefix=$MINGW_PREFIX && make && make install

#RUN cd /build/mingw-w64/mingw-w64-tools/widl && \
#    mkdir build && cd build && \
#    CC=gcc \
#    ../configure --prefix=$TOOLCHAIN_PREFIX --target=$TARGET_TUPLE && \
#    make -j4 && \
#    make install

RUN git clone -b master https://github.com/llvm-mirror/libcxx.git && \
    git clone -b master https://github.com/llvm-mirror/libcxxabi.git && \
    git clone -b master https://github.com/llvm-mirror/libunwind.git && \
    cd libcxx && \
    git checkout f45f32b0254e4107b4165ddc99ca2503ab9bd754 && \
    cd ../libcxxabi && \
    git checkout 05ba3281482304ae8de31123a594972a495da06d && \
    cd ../libunwind && \
    git checkout 2ddcf2461daa5d61c543474aed06b12a8b9ad816

COPY merge_archives.sh /build
RUN cd libunwind && \
    for arch in $TOOLCHAIN_ARCHS; do \
        mkdir build-$arch && cd build-$arch && cmake \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=$TOOLCHAIN_PREFIX/$arch-w64-mingw32 \
            -DCMAKE_C_COMPILER=$arch-w64-mingw32-clang \
            -DCMAKE_CXX_COMPILER=$arch-w64-mingw32-clang++ \
            -DCMAKE_CROSSCOMPILING=TRUE \
            -DCMAKE_SYSTEM_NAME=Windows \
            -DCMAKE_C_COMPILER_WORKS=TRUE \
            -DCMAKE_CXX_COMPILER_WORKS=TRUE \
            -DCMAKE_AR=$TOOLCHAIN_PREFIX/bin/llvm-ar \
            -DCMAKE_RANLIB=$TOOLCHAIN_PREFIX/bin/llvm-ranlib \
            -DLLVM_NO_OLD_LIBSTDCXX=TRUE \
            -DCXX_SUPPORTS_CXX11=TRUE \
            -DLIBUNWIND_USE_COMPILER_RT=TRUE \
            -DLIBUNWIND_ENABLE_THREADS=TRUE \
            -DLIBUNWIND_ENABLE_SHARED=FALSE \
            -DLIBUNWIND_ENABLE_CROSS_UNWINDING=FALSE \
            -DCMAKE_CXX_FLAGS="-I/build/libcxx/include" \
            .. && \
        make -j4 && make install && \
        /build/merge_archives.sh \
            $TOOLCHAIN_PREFIX/$arch-w64-mingw32/lib/libunwind.a \
            $TOOLCHAIN_PREFIX/$arch-w64-mingw32/lib/libpsapi.a && \
        cd .. || exit 1; \
    done

RUN cd libcxxabi && \
    for arch in $TOOLCHAIN_ARCHS; do \
        mkdir build-$arch && cd build-$arch && cmake \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=$TOOLCHAIN_PREFIX/$arch-w64-mingw32 \
            -DCMAKE_C_COMPILER=$arch-w64-mingw32-clang \
            -DCMAKE_CXX_COMPILER=$arch-w64-mingw32-clang++ \
            -DCMAKE_CROSSCOMPILING=TRUE \
            -DCMAKE_SYSTEM_NAME=Windows \
            -DCMAKE_C_COMPILER_WORKS=TRUE \
            -DCMAKE_CXX_COMPILER_WORKS=TRUE \
            -DCMAKE_AR=$TOOLCHAIN_PREFIX/bin/llvm-ar \
            -DCMAKE_RANLIB=$TOOLCHAIN_PREFIX/bin/llvm-ranlib \
            -DLIBCXXABI_USE_COMPILER_RT=ON \
            -DLIBCXXABI_ENABLE_EXCEPTIONS=ON \
            -DLIBCXXABI_ENABLE_THREADS=ON \
            -DLIBCXXABI_TARGET_TRIPLE=$arch-w64-mingw32 \
            -DLIBCXXABI_ENABLE_SHARED=OFF \
            -DLIBCXXABI_LIBCXX_INCLUDES=../../libcxx/include \
            -DLLVM_NO_OLD_LIBSTDCXX=TRUE \
            -DCXX_SUPPORTS_CXX11=TRUE \
            -DCMAKE_CXX_FLAGS="-D_LIBCPP_DISABLE_VISIBILITY_ANNOTATIONS" \
            .. && \
        make -j4 && \
        cd .. || exit 1; \
    done

RUN cd libcxx && \
    for arch in $TOOLCHAIN_ARCHS; do \
        mkdir build-$arch && cd build-$arch && cmake \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=$TOOLCHAIN_PREFIX/$arch-w64-mingw32 \
            -DCMAKE_C_COMPILER=$arch-w64-mingw32-clang \
            -DCMAKE_CXX_COMPILER=$arch-w64-mingw32-clang++ \
            -DCMAKE_CROSSCOMPILING=TRUE \
            -DCMAKE_SYSTEM_NAME=Windows \
            -DCMAKE_C_COMPILER_WORKS=TRUE \
            -DCMAKE_CXX_COMPILER_WORKS=TRUE \
            -DCMAKE_AR=$TOOLCHAIN_PREFIX/bin/llvm-ar \
            -DCMAKE_RANLIB=$TOOLCHAIN_PREFIX/bin/llvm-ranlib \
            -DLIBCXX_USE_COMPILER_RT=ON \
            -DLIBCXX_INSTALL_HEADERS=ON \
            -DLIBCXX_ENABLE_EXCEPTIONS=ON \
            -DLIBCXX_ENABLE_THREADS=ON \
            -DLIBCXX_ENABLE_MONOTONIC_CLOCK=ON \
            -DLIBCXX_ENABLE_SHARED=OFF \
            -DLIBCXX_SUPPORTS_STD_EQ_CXX11_FLAG=TRUE \
            -DLIBCXX_HAVE_CXX_ATOMICS_WITHOUT_LIB=TRUE \
            -DLIBCXX_ENABLE_EXPERIMENTAL_LIBRARY=OFF \
            -DLIBCXX_ENABLE_FILESYSTEM=OFF \
            -DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=TRUE \
            -DLIBCXX_CXX_ABI=libcxxabi \
            -DLIBCXX_CXX_ABI_INCLUDE_PATHS=../../libcxxabi/include \
            -DLIBCXX_CXX_ABI_LIBRARY_PATH=../../libcxxabi/build-$arch/lib \
            -DCMAKE_CXX_FLAGS="-D_LIBCXXABI_DISABLE_VISIBILITY_ANNOTATIONS" \
            .. && \
        make -j4 && make install && \
        /build/merge_archives.sh \
            $TOOLCHAIN_PREFIX/$arch-w64-mingw32/lib/libc++.a \
            $TOOLCHAIN_PREFIX/$arch-w64-mingw32/lib/libunwind.a && \
        cd .. || exit 1; \
    done

RUN cd $TOOLCHAIN_PREFIX/include && ln -s ../$(echo $TOOLCHAIN_ARCHS | awk '{print $1}')-w64-mingw32/include/c++ .

COPY hello.c hello.cpp hello-exception.cpp hello-tls.c /build/hello/
RUN cd hello && \
    for arch in $TOOLCHAIN_ARCHS; do \
        $arch-w64-mingw32-clang hello.c -o hello-$arch.exe || exit 1; \
    done

RUN cd hello && \
    for arch in $TOOLCHAIN_ARCHS; do \
        $arch-w64-mingw32-clang++ hello.cpp -o hello-cpp-$arch.exe -fno-exceptions || exit 1; \
    done

RUN cd hello && \
    for arch in $TOOLCHAIN_ARCHS; do \
        $arch-w64-mingw32-clang++ hello-exception.cpp -o hello-exception-$arch.exe || exit 1; \
    done

RUN cd hello && \
    for arch in $TOOLCHAIN_ARCHS; do \
        $arch-w64-mingw32-clang hello-tls.c -o hello-tls-$arch.exe || exit 1; \
    done

ENV AR=llvm-ar
ENV RANLIB=llvm-ranlib
ENV AS=llvm-as
ENV NM=llvm-nm
