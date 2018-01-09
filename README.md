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

The toolchain can be reproducibly built into a Docker image, or be
built and installed in the host environment (currently only tested
on Linux and macOS).

To build and install all components, just do:

    ./build-all.sh <target-dir>

To build the toolchain in Docker, run:

    docker build .

In addition to building the toolchain itself (just like `build-all.sh` does),
this also builds a few demo apps to show and verify that the toolchain works.

Other branches in this repo contain patches that might not have been
merged upstream yet, and tests of building third party projects using
the toolchain (in the branch `demoapps`).

For building projects that need more than just specifying
`CC=<triplet>-clang`, there is more (more or less hacky and in-progress)
setup for providing a larger selection of the tools that GNU binutils
normally provides, in the branch `tools`.

Individual components of the toolchain can be (re)built by running
the standalone shellscripts listed within `build-all.sh`. However, if
the source already is checked out, no effort is made to check out a
different version (if the build scripts have been updated to prefer
a different version) - and likewise, if configure flags in the build-*.sh
scripts have changed, you might need to wipe the build directory under
each project for the new configure options to be taken into use.



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

Additionally, one may run into other minor differences between GCC and clang.
