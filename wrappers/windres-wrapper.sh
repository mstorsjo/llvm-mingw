#!/bin/bash -e
#
# author: Josh de Kock <josh@itanimul.li>
#
# This is free and unencumbered software released into the public domain.
#
# Anyone is free to copy, modify, publish, use, compile, sell, or
# distribute this software, either in source code form or as a compiled
# binary, for any purpose, commercial or non-commercial, and by any
# means.
#
# In jurisdictions that recognize copyright laws, the author or authors
# of this software dedicate any and all copyright interest in the
# software to the public domain. We make this dedication for the benefit
# of the public at large and to the detriment of our heirs and
# successors. We intend this dedication to be an overt act of
# relinquishment in perpetuity of all present and future rights to this
# software under copyright law.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#
# For more information, please refer to <http://unlicense.org/>

PROG="$0"

CC=${CC:-i686-w64-mingw32-clang}

print_version () {
    cat <<EOF >&2
version: ?xd
EOF
    exit 1
}

print_help () {
 cat <<EOF >&2
usage: llvm-windres <OPTION> [INPUT-FILE] [OUTPUT-FILE]

LLVM Tool to manipulate Windows resources with a GNU windres interface.

Options:
  -i, --input <arg>          Name of the input file.
  -o, --output <arg>         Name of the output file.
  -J, --input-format <arg>   Input format to read.
  -O, --output-format <arg>  Output format to generate.
  --preprocessor <arg>       Custom preprocessor command.
  --preprocessor-arg <arg>   Preprocessor command arguments.
  -F, --target <arg>         Target for COFF objects to be compiled for.
  -I, --include-dir <arg>    Include directory to pass to preprocessor and resource compiler.
  -D, --define <arg[=val]>   Define to pass to preprocessor.
  -U, --undefine <arg[=val]> Undefine to pass to preprocessor.
  -c, --codepage <arg>       Default codepage to use when reading an rc file (0x0-0xffff).
  -v, --verbose              Enable verbose output.
  -V, --version              Display version.
  -h, --help                 Display this message and exit.
Input Formats:
  rc                         Text Windows Resource
  res                        Binary Windows Resource
Output Formats:
  res                        Binary Windows Resource
  coff                       COFF object
Targets:
  armv7-w64-mingw32
  aarch64-w64-mingw32
  i686-w64-mingw32
  x86_86-w64-mingw
EOF
    exit 1
}

error() {
    echo "${PROG}: error: $1" >&2
    exit 1
}

quote() {
    echo "$1" | sed -e "s|'|'\\\\''|g; 1s/^/'/; \$s/\$/'/"
}

INCLUDE=
VERBOSE=${VERBOSE:-false}
INPUT=-
OUTPUT=/dev/stdout
INPUT_FORMAT=rc
OUTPUT_FORMAT=res
TARGET=X64
CODEPAGE=

while [ $# != 0 ]; do
    case "$1" in
        "-i="*|"--input="*)
            INPUT="${1#*=}";;
        "-i"|"--input")
            INPUT="${2}"; shift;;
        "-o="*|"--output="*)
            OUTPUT="${1#*=}";;
        "-o"|"--output")
            OUTPUT="${2}"; shift;;
        "-J="*|"--input-format="*)
            INPUT_FORMAT="${1#*=}";;
        "-J"|"--input-format")
            INPUT_FORMAT="${2}"; shift;;
        "-O="*|"--output-format="*)
            OUTPUT_FORMAT="${1#*=}";;
        "-O"|"--output-format")
            OUTPUT_FORMAT="${2}"; shift;;
        "-F="*|"--target="*)
            TARGET="${1#*=}";;
        "-O"|"--output-format")
            TARGET="${2}"; shift;;
        "-I"|"--include-dir")
            INCLUDE="${INCLUDE} ${1#*=}"
            ;;
        "-I="*|"--include-dir="*)
            INCLUDE="${INCLUDE} ${2}"; shift
            ;;
        "-c"|"--codepage")
            CODEPAGE="${1#*=}"
            ;;
        "-c="*|"--codepage="*)
            CODEPAGE="${2}"; shift
            ;;
        "--preprocessor")
            error "ENOSYS"
            ;;
        "--preprocessor-arg")
            error "ENOSYS"
            ;;
        "-v"|"--verbose")
            VERBOSE=true
            ;;
        "-V"|"--version")
            print_version;;
        "--help"|"-h")
            print_help;;
        "-"*)
            error "unrecognized option: \`$1'"
            ;;
        *)
            error "rip: \`$1'"
    esac;
    shift
done

if $VERBOSE; then
    set -x
fi


TMPDIR="$(mktemp -d /tmp/windres.XXXXXXXXX)" || error "couldn't create temp dir"

case "${INPUT_FORMAT}" in
    "rc")
        $CC -E -P -xc -DRC_INVOKED=1 "${INPUT}" -o "${TMPDIR}/post.rc" || error "preprocessor failed"
        sed '/^#/d;/^$/d' "${TMPDIR}/post.rc" > "${TMPDIR}/in.rc"
        case "${OUTPUT_FORMAT}" in
            "res")
                llvm-rc "${TMPDIR}/in.rc" /FO "${TMPDIR}/out.res"
                cat "${TMPDIR}/out.res" > "${OUTPUT}"
                ;;
            "coff")
                llvm-rc "${TMPDIR}/in.rc" /FO "${TMPDIR}/in.res"
                llvm-cvtres "${TMPDIR}/in.res" /OUT:"${TMPDIR}/out.o"
                cat "${TMPDIR}/out.o" > "${OUTPUT}"
                ;;
            *)
                error "invalid output format: \`${OUTPUT_FORMAT}'"
        esac
        ;;
    "res")
        cat "${INPUT}" > "${TMPDIR}/in.rc"
        /usr/local/llvm-mingw/bin/llvm-rc "${TMPDIR}/in.res" /OUT:"${TMPDIR}/out.o"
        cat "${TMPDIR}/out.o" > "${OUTPUT}"
        ;;
    *)
        error "invalid input format: \`${INPUT_FORMAT}'"
esac
