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
- Support for generating debug info in PDB format
- Support for Address Sanitizer and Undefined Behaviour Sanitizer

Clang on its own can also be used as compiler in the normal GNU binutils
based environments though, so the main difference lies in replacing
binutils with LLVM based tools.

Installation
------------

Prebuilt docker linux images containing llvm-mingw are available from
[Docker Hub](https://hub.docker.com/r/mstorsjo/llvm-mingw/), and
prebuilt toolchains (both for use as cross compiler from linux, and
for use on windows) are available for download on GitHub. The toolchains
for windows come in 4 versions, one for each of the 4 supported
architectures, but each one of them can target all 4 architectures.

Building from source
--------------------

The toolchain can be reproducibly built into a Docker image, or be
built and installed in the host environment.

To build and install all components, just do:

    ./build-all.sh <target-dir>

To reduce the size of the installation, removing some files that
aren't necessary after building, run:

    ./strip-llvm.sh <target-dir>

To build a Docker image with the toolchain, run:

    docker build .

Individual components of the toolchain can be (re)built by running
the standalone shellscripts listed within `build-all.sh`. However, if
the source already is checked out, no effort is made to check out a
different version (if the build scripts have been updated to prefer
a different version) - and likewise, if configure flags in the build-\*.sh
scripts have changed, you might need to wipe the build directory under
each project for the new configure options to be taken into use.


Building in MSYS2
-----------------

To build in MSYS2, install the following set of packages with `pacman -S`:

    git subversion mingw-w64-x86_64-gcc mingw-w64-x86_64-ninja mingw-w64-x86_64-cmake make mingw-w64-x86_64-python2

Do note that this installs python2, not python3. python3 on windows
seems to have a bug in running subprocesses the way it's done by a
script in libcxx, a bug that only seems to be
[fixed in python 3.8](https://github.com/python/cpython/commit/9e3c4526394856d6376eed4968d27d53e1d69b7d).


Status
------

The toolchain currently does support both C and C++, including support
for exception handling.

It is in practice new and hasn't been tested with quite as many projects
as the regular GCC/binutils based toolchains yet. You might run into issues
building non-trivial projects.


Known issues
------------

LLD, the LLVM linker, is what causes most of the major differences to the
normal GCC/binutils based MinGW.

- The windres replacement, llvm-rc, isn't very mature and doesn't support
  everything that GNU windres does.
- The toolchain defaults to using the Universal CRT (which is only available
  out of the box since Windows 10, but can be installed on Vista or newer)
  and defaults to targeting Vista. These defaults can be changed in
  `build-mingw-w64.sh` though.
- The toolchain uses Windows native TLS support, which doesn't work properly
  until Windows Vista. This has no effect on code not using thread local
  variables.
- The runtime libraries libunwind, libcxxabi and libcxx also assume that the
  target is Vista or newer.
- Address Sanitizer doesn't produce working backtraces for i686. Address
  Sanitizer requires using a PDB file for symbolizing the error location and
  backtraces.
- The sanitizers are only supported on x86.

Additionally, one may run into other minor differences between GCC and clang.

PDB support
-----------

LLVM does [support](http://blog.llvm.org/2017/08/llvm-on-windows-now-supports-pdb-debug.html)
generating debug info in the PDB format. Since GNU binutils based mingw
environments don't support this, there's no predecent for what command
line parameters to use for this, and llvm-mingw produces debug info in
DWARF format by default.

To produce debug info in PDB format, you currently need to do the following
changes:

- Add `-gcodeview` to the compilation commands (e.g. in
  `wrappers/clang-target-wrapper.sh`), together with using `-g` as usual to
  enable debug info in general.
- Add `-Wl,-pdb=` to linking commands. This creates a PDB file at the same
  location as the output EXE/DLL, but with a PDB extension. (By passing
  `-Wl,-pdb=module.pdb` or `-Wl,-pdb,module.pdb` one can explicitly specify
  the name of the output PDB file.)

Even though LLVM supports this, there are a few caveats with using it when
building in MinGW mode:

- Microsoft debuggers might have assumptions about the C++ ABI used, which
  doesn't hold up with the Itanium ABI used in MinGW.
- This is unimplemented for the armv7 target, and while implemented for aarch64,
  it doesn't seem to work properly there yet.
