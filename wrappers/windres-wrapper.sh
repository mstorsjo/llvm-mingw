#!/bin/sh -e
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

print_version () {
    cat <<EOF >&2
version: LLVM windres (GNU Binutils compatible) 0.1
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
  x86_86-w64-mingw32
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
OUTPUT_FORMAT=coff
CODEPAGE=1252
CPP_OPTIONS=
TARGET="$(basename $0 | sed 's/-[^-]*$//')"

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
        "-F"|"--target")
            TARGET="${2}"; shift;;
        "-I"|"--include-dir")
            INCLUDE="${INCLUDE} ${2}"; shift;;
        "--include-dir="*)
            INCLUDE="${INCLUDE} ${1#*=}";;
        "-I"*)
            INCLUDE="${INCLUDE} ${1#-I}";;
        "-c"|"--codepage")
            CODEPAGE="${1#*=}";;
        "-c="*|"--codepage="*)
            CODEPAGE="${2}"; shift;;
        "--preprocessor")
            error "ENOSYS";;
        "--preprocessor-arg")
            error "ENOSYS";;
        "-D"*)
            CPP_OPTIONS="$CPP_OPTIONS $1";;
        "-D"|"--define")
            CPP_OPTIONS="$CPP_OPTIONS -D$2"; shift;;
        "-v"|"--verbose")
            VERBOSE=true;;
        "-V"|"--version")
            print_version;;
        "--help"|"-h")
            print_help;;
        "-"*)
            error "unrecognized option: \`$1'";;
        *)
            if [ "$INPUT" = "-" ]; then
                INPUT="$1"
            elif [ "$OUTPUT" = "/dev/stdout" ]; then
                OUTPUT="$1"
            else
                error "rip: \`$1'"
            fi
    esac
    shift
done

ARCH=$(echo $TARGET | sed 's/-.*//')
case $ARCH in
i686)    M=X86 ;;
x86_64)  M=X64 ;;
armv7)   M=ARM ;;
aarch64) M=ARM64 ;;
esac

: ${CC:-$ARCH-w64-mingw32-clang}

if $VERBOSE; then
    set -x
fi

for i in $INCLUDE; do
    CPP_OPTIONS="$CPP_OPTIONS -I$i"
    RC_OPTIONS="$RC_OPTIONS -I $i"
done

TMPDIR="$(mktemp -d /tmp/windres.XXXXXXXXX)" || error "couldn't create temp dir"

cleanup() {
    if ! $VERBOSE; then
        rm -rf "$TMPDIR"
    fi
}

trap 'cleanup' EXIT

case "${INPUT_FORMAT}" in
    "rc")
        $CC -E $(echo $CPP_OPTIONS | sed 's/\\"/"/g') -xc -DRC_INVOKED=1 "${INPUT}" -o "${TMPDIR}/post.rc" || error "preprocessor failed"

        # Parse the preprocessor output, looking for source file/line markers,
        # and discard output from *.h files. This matches what rc.exe and binutils windres
        # do.
        IFS='
'
        output=0
        rm -f "${TMPDIR}/in.rc"
        for line in $(cat "${TMPDIR}/post.rc"); do
            case $line in
            \#\ *)
                file="$(echo "$line" | awk '{print $3}' | sed 's/^"//;s/"$//')"
                case $file in
                *.h)
                    output=0
                    ;;
                *)
                    output=1
                    ;;
                esac
                ;;
            *)
                if [ $output -ne 0 ]; then
                    echo "$line" >> "${TMPDIR}/in.rc"
                fi
                ;;
            esac
        done
        unset IFS

        llvm-rc $RC_OPTIONS "${TMPDIR}/in.rc" /C $CODEPAGE /FO "${TMPDIR}/in.res"
        case "${OUTPUT_FORMAT}" in
            "res")
                cat "${TMPDIR}/in.res" > "${OUTPUT}"
                ;;
            "coff")
                llvm-cvtres "${TMPDIR}/in.res" /MACHINE:${M} /OUT:"${TMPDIR}/out.o"
                cat "${TMPDIR}/out.o" > "${OUTPUT}"
                ;;
            *)
                error "invalid output format: \`${OUTPUT_FORMAT}'"
        esac
        ;;
    "res")
        cat "${INPUT}" > "${TMPDIR}/in.rc"
        llvm-cvtres "${TMPDIR}/in.res" /MACHINE:${M} /FO "${TMPDIR}/out.o"
        cat "${TMPDIR}/out.o" > "${OUTPUT}"
        ;;
    *)
        error "invalid input format: \`${INPUT_FORMAT}'"
esac

