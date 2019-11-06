/*
 * author: Josh de Kock <josh@itanimul.li>, Martin Storsjo <martin@martin.st>
 *
 * This is free and unencumbered software released into the public domain.
 *
 * Anyone is free to copy, modify, publish, use, compile, sell, or
 * distribute this software, either in source code form or as a compiled
 * binary, for any purpose, commercial or non-commercial, and by any
 * means.
 *
 * In jurisdictions that recognize copyright laws, the author or authors
 * of this software dedicate any and all copyright interest in the
 * software to the public domain. We make this dedication for the benefit
 * of the public at large and to the detriment of our heirs and
 * successors. We intend this dedication to be an overt act of
 * relinquishment in perpetuity of all present and future rights to this
 * software under copyright law.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 * IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
 * OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
 * ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 *
 * For more information, please refer to <http://unlicense.org/>
 */

#include "native-wrapper.h"

#ifndef CC
#define CC "clang"
#endif

#ifndef LLVM_RC
#define LLVM_RC "llvm-rc"
#endif

#ifndef LLVM_CVTRES
#define LLVM_CVTRES "llvm-cvtres"
#endif

#ifndef DEFAULT_TARGET
#define DEFAULT_TARGET "x86_64-w64-mingw32"
#endif

#include <stdarg.h>

#ifdef _WIN32
#else
#define _tspawnvp_escape _spawnvp

#include <sys/wait.h>
#include <errno.h>

#define _P_WAIT 0
static int _spawnvp(int mode, const char *filename, const char * const *argv) {
    pid_t pid;
    if (!(pid = fork())) {
        execvp(filename, (char **) argv);
        perror(filename);
        exit(1);
    }
    int stat = 0;
    if (waitpid(pid, &stat, 0) == -1)
        return -1;
    if (WIFEXITED(stat))
        return WEXITSTATUS(stat);
    errno = EIO;
    return -1;
}
#endif

// GNU binutils windres seem to require an extra level of escaping of
// -D options to the preprocessor, which we need to undo here.
// For defines that produce quoted strings, this windres frontend is
// called with parameters like this: -DSTRING=\\\"1.2.3\\\"
static const TCHAR *unescape_cpp(const TCHAR *str) {
    TCHAR *out = _tcsdup(str);
    int len = _tcslen(str);
    int i, outpos = 0;
    for (i = 0; i < len - 1; i++) {
        if (str[i] == '\\' && str[i + 1] == '"')
            continue;
        out[outpos++] = str[i];
    }
    while (i < len)
        out[outpos++] = str[i++];
    out[outpos++] = '\0';
    return out;
}

static void print_version(void) {
    printf(
"version: LLVM windres (GNU windres compatible) 0.1\n"
    );
    exit(1);
}

static void print_help(void) {
    printf(
"usage: llvm-windres <OPTION> [INPUT-FILE] [OUTPUT-FILE]\n"
"\n"
"LLVM Tool to manipulate Windows resources with a GNU windres interface.\n"
"\n"
"Options:\n"
"  -i, --input <arg>          Name of the input file.\n"
"  -o, --output <arg>         Name of the output file.\n"
"  -J, --input-format <arg>   Input format to read.\n"
"  -O, --output-format <arg>  Output format to generate.\n"
"  --preprocessor <arg>       Custom preprocessor command.\n"
"  --preprocessor-arg <arg>   Preprocessor command arguments.\n"
"  -F, --target <arg>         Target for COFF objects to be compiled for.\n"
"  -I, --include-dir <arg>    Include directory to pass to preprocessor and resource compiler.\n"
"  -D, --define <arg[=val]>   Define to pass to preprocessor.\n"
"  -U, --undefine <arg[=val]> Undefine to pass to preprocessor.\n"
"  -c, --codepage <arg>       Default codepage to use when reading an rc file (0x0-0xffff).\n"
"      --use-temp-file        Use a temporary file for the preprocessing output.\n"
"  -v, --verbose              Enable verbose output.\n"
"  -V, --version              Display version.\n"
"  -h, --help                 Display this message and exit.\n"
"Input Formats:\n"
"  rc                         Text Windows Resource\n"
"  res                        Binary Windows Resource\n"
"Output Formats:\n"
"  res                        Binary Windows Resource\n"
"  coff                       COFF object\n"
"Targets:\n"
"  armv7-w64-mingw32\n"
"  aarch64-w64-mingw32\n"
"  i686-w64-mingw32\n"
"  x86_86-w64-mingw32\n"
    );
    exit(1);
}

static void error(const TCHAR *basename, const TCHAR *fmt, ...) {
    _ftprintf(stderr, _T(TS": error: "), basename);
    va_list ap;
    va_start(ap, fmt);
    _vftprintf(stderr, fmt, ap);
    _ftprintf(stderr, _T("\n"));
    va_end(ap);
    exit(1);
}

static void print_argv(const TCHAR **exec_argv) {
    while (*exec_argv) {
        _ftprintf(stderr, _T(TS" "), *exec_argv);
        exec_argv++;
    }
    _ftprintf(stderr, _T("\n"));
}

static void check_num_args(int arg, int max_arg) {
    if (arg > max_arg) {
        fprintf(stderr, "Too many options added\n");
        abort();
    }
}

int _tmain(int argc, TCHAR* argv[]) {
    const TCHAR *dir;
    const TCHAR *basename;
    const TCHAR *target;
    split_argv(argv[0], &dir, &basename, &target, NULL);
    if (!target)
        target = _T(DEFAULT_TARGET);

    const TCHAR *bfd_target = NULL;
    const TCHAR *input = _T("-");
    const TCHAR *output = _T("/dev/stdout");
    const TCHAR *input_format = _T("rc");
    const TCHAR *output_format = _T("coff");
    const TCHAR **includes = malloc(argc * sizeof(*includes));
    int nb_includes = 0;
    const TCHAR *codepage = _T("1252");
    const TCHAR **cpp_options = malloc(argc * sizeof(*cpp_options));
    int nb_cpp_options = 0;
    int verbose = 0;

#define _tcsstart(a, b) !_tcsncmp(a, b, sizeof(b)/sizeof(TCHAR) - 1)

#define IF_MATCH_EITHER(short, long) \
    if (!_tcscmp(argv[i], _T(short)) || !_tcscmp(argv[i], _T(long)))
#define OPTION(short, long, var) \
    if (_tcsstart(argv[i], _T(short "=")) || _tcsstart(argv[i], _T(long "="))) { \
        var = _tcschr(argv[i], '=') + 1; \
    } else IF_MATCH_EITHER(short, long) { \
        if (i + 1 < argc) \
            var = argv[++i]; \
        else \
            error(basename, _T(TS" missing argument"), argv[i]); \
    }
#define SEPARATE_ARG(var) do { \
        if (i + 1 < argc) \
            var = argv[++i]; \
        else \
            error(basename, _T(TS" missing argument"), argv[i]); \
    } while (0)
#define SEPARATE_ARG_PREFIX(var, prefix) do { \
        if (i + 1 < argc) \
            var = concat(_T(prefix), argv[++i]); \
        else \
            error(basename, _T(TS" missing argument"), argv[i]); \
    } while (0)

    for (int i = 1; i < argc; i++) {
        OPTION("-i", "--input", input)
        else OPTION("-o", "--output", output)
        else OPTION("-J", "--input-format", input_format)
        else OPTION("-O", "--output-format", output_format)
        else OPTION("-F", "--target", bfd_target)
        else IF_MATCH_EITHER("-I", "--include-dir") {
            SEPARATE_ARG(includes[nb_includes++]);
        } else if (_tcsstart(argv[i], _T("--include-dir="))) {
            includes[nb_includes++] = _tcschr(argv[i], '=') + 1;
        } else if (_tcsstart(argv[i], _T("-I"))) {
            includes[nb_includes++] = argv[i] + 2;
        } else OPTION("-c", "--codepage", codepage)
        else if (!_tcscmp(argv[i], _T("--preprocessor"))) {
            error(basename, _T("ENOSYS"));
        } else if (_tcsstart(argv[i], _T("--preprocessor-arg="))) {
            cpp_options[nb_cpp_options++] = _tcschr(argv[i], '=') + 1;
        } else if (!_tcscmp(argv[i], _T("--preprocessor-arg"))) {
            SEPARATE_ARG(cpp_options[nb_cpp_options++]);
        } else IF_MATCH_EITHER("-D", "--define") {
            SEPARATE_ARG_PREFIX(cpp_options[nb_cpp_options++], "-D");
        } else if (_tcsstart(argv[i], _T("-D"))) {
            cpp_options[nb_cpp_options++] = argv[i];
        } else IF_MATCH_EITHER("-U", "--undefine") {
            SEPARATE_ARG_PREFIX(cpp_options[nb_cpp_options++], "-U");
        } else if (_tcsstart(argv[i], _T("-U"))) {
            cpp_options[nb_cpp_options++] = argv[i];
        } else IF_MATCH_EITHER("-v", "--verbose") {
            verbose = 1;
        } else IF_MATCH_EITHER("-V", "--version") {
            print_version();
        } else IF_MATCH_EITHER("-h", "--help") {
            print_help();
        } else if (!_tcscmp(argv[i], _T("--use-temp-file"))) {
            // No-op, we use a temp file by default.
        } else if (_tcsstart(argv[i], _T("-"))) {
            error(basename, _T("unrecognized option: `"TS"'"), argv[i]);
        } else {
            if (!_tcscmp(input, _T("-")))
                input = argv[i];
            else if (!_tcscmp(output, _T("/dev/stdout")))
                output = argv[i];
            else
                error(basename, _T("rip: `"TS"'"), argv[i]);
        }
    }
    if (bfd_target) {
        if (!_tcscmp(bfd_target, _T("pe-x86-64")) ||
            !_tcscmp(bfd_target, _T("pei-x86-64")))
            target = _T("x86_64-w64-mingw32");
        else if (!_tcscmp(bfd_target, _T("pe-i386")) ||
                 !_tcscmp(bfd_target, _T("pei-x86-64")))
            target = _T("x86_64-w64-mingw32");
        else
            error(basename, _T("unsupported target: `"TS"'"), bfd_target);
    }

    TCHAR *arch = _tcsdup(target);
    TCHAR *dash = _tcschr(arch, '-');
    if (dash)
        *dash = '\0';

    const TCHAR *machine = _T("unknown");
    if (!_tcscmp(arch, _T("i686")))
        machine = _T("X86");
    else if (!_tcscmp(arch, _T("x86_64")))
        machine = _T("X64");
    else if (!_tcscmp(arch, _T("armv7")))
        machine = _T("ARM");
    else if (!_tcscmp(arch, _T("aarch64")))
        machine = _T("ARM64");

    const TCHAR *resolved_CC =
        concat(dir, concat(target, _T("-") _T(CC)));
    const TCHAR *resolved_LLVM_RC =
        concat(dir, concat(target, _T("-") _T(LLVM_RC)));
    const TCHAR *resolved_LLVM_CVTRES =
        concat(dir, concat(target, _T("-") _T(LLVM_CVTRES)));

    const TCHAR **rc_options = malloc(2 * argc * sizeof(*cpp_options));
    int nb_rc_options = 0;
    for (int i = 0; i < nb_includes; i++) {
        cpp_options[nb_cpp_options++] = concat(_T("-I"), includes[i]);
        rc_options[nb_rc_options++] = _T("-I");
        rc_options[nb_rc_options++] = includes[i];
    }

    for (int i = 0; i < nb_cpp_options; i++)
        cpp_options[i] = unescape_cpp(cpp_options[i]);

    const TCHAR *preproc_rc = concat(output, _T(".preproc.rc"));
    const TCHAR *res = concat(output, _T(".out.res"));

    TCHAR *inputdir = _tcsdup(input);
    {
        TCHAR *sep = _tcsrchrs(inputdir, '/', '\\');
        if (sep)
            *sep = '\0';
        else
            inputdir = _tcsdup(_T("."));
    }


    int max_arg = 2 * argc + 20;
    const TCHAR **exec_argv = malloc((max_arg + 1) * sizeof(*exec_argv));
    int arg = 0;

    if (!_tcscmp(input_format, _T("rc"))) {
        exec_argv[arg++] = resolved_CC;
        exec_argv[arg++] = _T("-E");
        for (int i = 0; i < nb_cpp_options; i++)
            exec_argv[arg++] = cpp_options[i];
        exec_argv[arg++] = _T("-xc");
        exec_argv[arg++] = _T("-DRC_INVOKED=1");
        exec_argv[arg++] = input;
        exec_argv[arg++] = _T("-o");
        exec_argv[arg++] = preproc_rc;
        exec_argv[arg] = NULL;

        check_num_args(arg, max_arg);
        if (verbose)
            print_argv(exec_argv);
        int ret = _tspawnvp_escape(_P_WAIT, exec_argv[0], exec_argv);
        if (ret == -1) {
            _tperror(exec_argv[0]);
            return 1;
        }
        if (ret != 0) {
            error(basename, _T("preprocessor failed"));
            return ret;
        }

        arg = 0;
        exec_argv[arg++] = resolved_LLVM_RC;
        for (int i = 0; i < nb_rc_options; i++)
            exec_argv[arg++] = rc_options[i];
        exec_argv[arg++] = _T("-I");
        exec_argv[arg++] = inputdir;
        exec_argv[arg++] = preproc_rc;
        exec_argv[arg++] = _T("-c");
        exec_argv[arg++] = codepage;
        exec_argv[arg++] = _T("-fo");
        if (!_tcscmp(output_format, _T("res")))
            exec_argv[arg++] = output;
        else
            exec_argv[arg++] = res;
        exec_argv[arg] = NULL;

        check_num_args(arg, max_arg);
        if (verbose)
            print_argv(exec_argv);
        ret = _tspawnvp_escape(_P_WAIT, exec_argv[0], exec_argv);
        if (ret == -1) {
            _tperror(exec_argv[0]);
            return 1;
        }
        if (ret != 0) {
            error(basename, _T("llvm-rc failed"));
            if (!verbose)
                _tunlink(preproc_rc);
            return ret;
        }

        if (!_tcscmp(output_format, _T("res"))) {
            // All done
        } else if (!_tcscmp(output_format, _T("coff"))) {
            arg = 0;
            exec_argv[arg++] = resolved_LLVM_CVTRES;
            exec_argv[arg++] = res;
            exec_argv[arg++] = concat(_T("-machine:"), machine);
            exec_argv[arg++] = concat(_T("-out:"), output);
            exec_argv[arg] = NULL;

            check_num_args(arg, max_arg);
            if (verbose)
                print_argv(exec_argv);
            int ret = _tspawnvp_escape(_P_WAIT, exec_argv[0], exec_argv);
            if (ret == -1) {
                _tperror(exec_argv[0]);
                return 1;
            }
            if (!verbose) {
                _tunlink(preproc_rc);
                _tunlink(res);
            }
            return ret;
        } else {
            error(basename, _T("invalid output format: `"TS"'"), output_format);
        }
    } else if (!_tcscmp(input_format, _T("res"))) {
        exec_argv[arg++] = resolved_LLVM_CVTRES;
        exec_argv[arg++] = input;
        exec_argv[arg++] = concat(_T("-machine:"), machine);
        exec_argv[arg++] = concat(_T("-out:"), output);
        exec_argv[arg] = NULL;

        check_num_args(arg, max_arg);
        if (verbose)
            print_argv(exec_argv);
        int ret = _tspawnvp_escape(_P_WAIT, exec_argv[0], exec_argv);
        if (ret == -1) {
            _tperror(exec_argv[0]);
            return 1;
        }
        return ret;
    } else {
        error(basename, _T("invalid input format: `"TS"'"), input_format);
    }

    return 0;
}
