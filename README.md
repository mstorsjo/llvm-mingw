LLVM MinGW
==========

This is a recipe for reproducibly building a
[LLVM](https://llvm.org)/[Clang](https://clang.llvm.org/)/[LLD](https://lld.llvm.org/)
based mingw-w64 toolchain.

Benefits of a LLVM based MinGW toolchain are:
- Support for targeting ARM/ARM64 (while GCC obviously does support
  these architectures, it doesn't support Windows on ARM)
- A single toolchain targeting all four architectures (i686, x86_64,
  armv7 and arm64) instead of separate compiler binaries for each
  architecture

Clang on its own can also be used as compiler in the normal GNU binutils
based environments though, so the main difference lies in replacing
binutils with LLVM based tools.

This is similar to https://github.com/martell/mingw-w64-clang, with
the exact same goal but with a slightly different mechanism for
building it, allowing a full from-scratch build of all components
in one command.

The only prerequisite for building is Docker; you can also follow the
steps of the Dockerfile and build manually within a normal linux
environment, but Docker provides reproducibility by building in a known,
empty environment.

To build, just do:

    docker build .

This will download and build all parts of the toolchain, and build a few
demo apps to show and verify that the toolchain works.


Other branches in this repo contain patches that might not have been
merged upstream yet, and tests of building third party projects using
the toolchain. This includes more tool frontends/wrappers with the
usual binutils names, to allow using it as a drop-in replacement for
a normal MinGW toolchain.


If the toolchain is used in an environment that already have got a
normal GCC based MinGW toolchain with the same triplet prefix in
the same path, you may need to add
`--sysroot=path/to/prefix/x86_64-w64-mingw32` to the clang commands.

Status
------

The toolchain currently does support both C and C++, including support
for exception handling.

It is in practice quite new and immature and haven't been proven with a
large number of projects yet though. You will probably run into issues
building non-trivial projects.


Known issues
------------

LLD, the LLVM linker, is what causes most of the major differences to the
normal GCC/binutils based MinGW.

- LLD doesn't support using import libraries created by GNU tools.
- LLD doesn't automatically fix up use of data symbols from DLLs without
  the dllimport attributes.
- The C++ libraries ([libcxxabi](http://libcxxabi.llvm.org/), [libcxx](http://libcxx.llvm.org/)) can only be linked statically
  at the moment.
- The C++ libraries and unwinder aren't built with exceptions support for
  ARM64 target at the moment. (The toolchain and libraries themselves do
  support it though.)
- The ARM64 target doesn't support thread local variables.

Additionally, one may run into other minor differences between GCC and clang.


Use outside of Docker
---------------------

To use a similar toolchain outside of Docker, you can run the same build
commands as the dockerfile in probably most recent linux distributions.
The build procedure is currently only maintained as a Dockerfile, for ease
of verification, reproducibility and ease of maintainance though.

The toolchain that was built within the docker image can also be
extracted from the image into the surrounding host environment.
The `extract-docker.sh` script can copy out a directory from a
built docker image, either for getting the toolchain or built test
binaries, when given a docker tag or image id.

If the `docker build` command ended with e.g.
`Successfully built d8b13aad965a`, you can run:

    ./extract-docker.sh d8b13aad965a prefix

This copies the directory `prefix` (which contains the whole toolchain,
with headers and link libraries for all four architectures) from the
built docker image into the current directory.
The Dockerfile currently builds in an Ubuntu 16.04 environment, so the
extracted toolchain can at least be used in such an environment.

The extracted toolchain can be used by adding `prefix/bin` to `$PATH`
and calling e.g. `x86_64-w64-ming32-clang`.
