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
- Since LLVM 16: Support for [Control Flow Guard](https://github.com/mstorsjo/llvm-mingw/issues/301)
  (`-mguard=cf` compile and link flags)

Clang on its own can also be used as compiler in the normal GNU binutils
based environments though, so the main difference lies in replacing
binutils with LLVM based tools.

Releases
--------

The [GitHub Releases](https://github.com/mstorsjo/llvm-mingw/releases)
page contains prebuilt toolchains that can be downloaded and installed
by just unpacking them.

They come primarily in two different forms; packages named
`llvm-mingw-<version>-<crt>-ubuntu-<distro_version>-<arch>.tar.xz`
are cross compilers, that can be run on Linux, compiling binaries
for any of the 4 target Windows architectures. Packages named
`llvm-mingw-<version>-<crt>-<arch>.zip` are native toolchains that
run on Windows (with binaries in the specified architecture), but
which all can compile binaries for any of the 4 architectures.

The cross compilers come in versions running on either x86_64 or
aarch64. (They're built on Ubuntu, but hopefully do run on other
contempory distributions as well.)

There are packages with two different choices of CRT (C runtime) - the
primary target is UCRT (the Universal C Runtime). The UCRT
is available preinstalled since Windows 10, but can be installed
on top of Vista or newer. The other legacy alternative is `msvcrt`,
which produces binaries for (and uses) msvcrt.dll, which is a
built-in component in all versions of Windows. This allows running
directly out of the box on older versions of Windows too, without
ensuring that the UCRT is installed, but msvcrt.dll is generally
less featureful. Address Sanitizer only works properly with UCRT.

In addition to the downloadable toolchain packges, there are also
prebuilt docker linux images containing the llvm-mingw toolchain,
available from [Docker Hub](https://hub.docker.com/r/mstorsjo/llvm-mingw/).

There are also [nightly builds](https://github.com/mstorsjo/llvm-mingw/releases/tag/nightly)
with the very latest versions of LLVM and mingw-w64 from git.

Building from source
--------------------

The toolchain can be compiled for installation in the current Unix
environment, fetching sources as needed:

    ./build-all.sh <target-dir>

It can also be built, reproducibly, into a Docker image:

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

To build in MSYS2, install the following set of packages with `pacman -S --needed`:

    git wget mingw-w64-x86_64-gcc mingw-w64-x86_64-ninja mingw-w64-x86_64-cmake make mingw-w64-x86_64-python3 autoconf libtool


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

- As this toolchain uses a different CRT and C++ standard library than
  most mingw toolchains, it is incompatible with object files and
  static libraries built with other toolchains. Mixing DLLs from other
  toolchains is supported, but only as long as CRT resources aren't
  shared across DLL boundaries (no sharing of file handles etc, and memory
  should be freed by the same DLL that allocated it).
- The windres replacement, llvm-rc, isn't very mature and doesn't support
  everything that GNU windres does.
- The toolchain defaults to using the Universal CRT (which is only available
  out of the box since Windows 10, but can be installed on Vista or newer)
  and defaults to targeting Windows 7. These defaults can be changed in
  `build-mingw-w64.sh` though.
- The toolchain uses Windows native TLS support, which doesn't work properly
  until Windows Vista. This has no effect on code not using thread local
  variables.
- The runtime libraries libunwind, libcxxabi and libcxx also assume that the
  target is Windows 7 or newer.
- Address Sanitizer doesn't produce working backtraces for i686. Address
  Sanitizer requires using a PDB file for symbolizing the error location and
  backtraces.
- The sanitizers are only supported on x86.
- LLD doesn't support linker script (in the COFF part of LLD). Linker script can be used for
  reprogramming how the linker lays out the output, but is in most cases
  in MinGW setups only used for passing lists of object files to link.
  Passing lists of files can also be done with response files, which LLD does support.
  (This was fixed in qmake in [v5.12.0](https://code.qt.io/cgit/qt/qtbase.git/commit/?id=d92c25b1b4ac0423a824715a08b2db2def4b6e25), to use response
  files instead of linker script.)
- Libtool based projects fail to link with llvm-mingw if the project contains
  C++. (This often manifests with undefined symbols like `___chkstk_ms`,
  `__alloca` or `___divdi3`.)
  For such targets, libtool tries to detect which libraries to link
  by invoking the compiler with `$CC -v` and picking up the libraries that
  are linked by default, and then invoking the linker driver with `-nostdlib`
  and specifying the default libraries manually. In doing so, libtool fails
  to detect when clang is using compiler_rt instead of libgcc, because
  clang refers to it as an absolute path to a static library, instead of
  specifying a library path with `-L` and linking the library with `-l`.
  Clang is [reluctant to changing this behaviour](https://reviews.llvm.org/D51440).
  A [bug](https://debbugs.gnu.org/cgi/bugreport.cgi?bug=27866) has been filed
  with libtool, but no fix has been committed, and as libtool files are
  shipped with the projects that use them (bundled within the configure
  script), one has to update the configure script in each project to avoid
  the issue. This can either be done by installing libtool, patching it
  and running `autoreconf -fi` in the project, or by manually applying the
  fix on the shipped `configure` script. A patched version of libtool is
  [shipped in MSYS2](https://github.com/msys2/MINGW-packages/blob/95b093e888/mingw-w64-libtool/0011-Pick-up-clang_rt-static-archives-compiler-internal-l.patch)
  at least.
- Libtool, when running on Windows, prefers using linker script over
  response files, to pass long lists of object files to the linker driver,
  but LLD doesn't support linker script (as described above). This issue
  produces errors like `lld-link: error: .libs\libfoobar.la.lnkscript: unknown file type`.
  To fix this, the bundled libtool scripts has to be fixed like explained
  above, but this fix requires changes both to `configure` and a separate
  file named `ltmain.{in,sh}`. A fix for this is also
  [shipped in MSYS2](https://github.com/msys2/MINGW-packages/blob/95b093e888/mingw-w64-libtool/0012-Prefer-response-files-over-linker-scripts-for-mingw-.patch).

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
- Add `-Wl,--pdb=` to linking commands. This creates a PDB file at the same
  location as the output EXE/DLL, but with a PDB extension. (By passing
  `-Wl,--pdb=module.pdb` one can explicitly specify the name of the output
  PDB file.)

Even though LLVM supports this, there are some caveats with using it when
building in MinGW mode; Microsoft debuggers might have assumptions about
the C++ ABI used, which doesn't hold up with the Itanium ABI used in MinGW.
