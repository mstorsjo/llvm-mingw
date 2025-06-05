ARG BASE=mstorsjo/llvm-mingw:dev
FROM $BASE

COPY build-compiler-rt.sh build-llvm.sh ./
RUN ./build-compiler-rt.sh --native $TOOLCHAIN_PREFIX

RUN export PATH=$TOOLCHAIN_PREFIX/bin:$PATH && \
    ./build-llvm.sh /tmp/dummy-prefix --disable-lldb --disable-clang-tools-extra --with-clang --disable-dylib --instrumented

COPY pgo-training.sh pgo-training.make ./
COPY test/ ./test/
RUN ./pgo-training.sh llvm-project/llvm/build-instrumented $TOOLCHAIN_PREFIX
