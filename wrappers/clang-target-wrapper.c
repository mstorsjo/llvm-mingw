/*
 * Copyright (c) 2018 Martin Storsjo
 *
 * This file is part of llvm-mingw.
 *
 * Permission to use, copy, modify, and/or distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

#ifdef UNICODE
#define _UNICODE
#endif

#ifndef CLANG
#define CLANG "clang"
#endif
#ifndef DEFAULT_TARGET
#define DEFAULT_TARGET "x86_64-w64-mingw32"
#endif

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <tchar.h>
#include <windows.h>
#include <process.h>
#define EXECVP_CAST
#else
#include <unistd.h>
typedef char TCHAR;
#define _T(x) x
#define _tcsrchr strrchr
#define _tcschr strchr
#define _tcsdup strdup
#define _tcscpy strcpy
#define _tcslen strlen
#define _tcscmp strcmp
#define _tperror perror
#define _texecvp execvp
#define _tmain main
#define EXECVP_CAST (char **)
#endif

static TCHAR *escape(const TCHAR *str) {
#ifdef _WIN32
    TCHAR *out = malloc((_tcslen(str) * 2 + 3) * sizeof(*out));
    TCHAR *ptr = out;
    int i;
    *ptr++ = '"';
    for (i = 0; str[i]; i++) {
        if (str[i] == '"') {
            int j = i - 1;
            // Before all double quotes, backslashes need to be escaped, but
            // not elsewhere.
            while (j >= 0 && str[j--] == '\\')
                *ptr++ = '\\';
            // Escape the next double quote.
            *ptr++ = '\\';
        }
        *ptr++ = str[i];
    }
    // Any final backslashes, before the quote around the whole argument,
    // need to be doubled.
    int j = i - 1;
    while (j >= 0 && str[j--] == '\\')
        *ptr++ = '\\';
    *ptr++ = '"';
    *ptr++ = '\0';
    return out;
#else
    return _tcsdup(str);
#endif
}

static TCHAR *concat(const TCHAR *prefix, const TCHAR *suffix) {
    int prefixlen = _tcslen(prefix);
    int suffixlen = _tcslen(suffix);
    TCHAR *buf = malloc((prefixlen + suffixlen + 1) * sizeof(*buf));
    _tcscpy(buf, prefix);
    _tcscpy(buf + prefixlen, suffix);
    return buf;
}

static TCHAR *_tcsrchrs(const TCHAR *str, TCHAR char1, TCHAR char2) {
    TCHAR *ptr1 = _tcsrchr(str, char1);
    TCHAR *ptr2 = _tcsrchr(str, char2);
    if (!ptr1)
        return ptr2;
    if (!ptr2)
        return ptr1;
    if (ptr1 < ptr2)
        return ptr2;
    return ptr1;
}

int _tmain(int argc, TCHAR* argv[]) {
    const TCHAR *argv0 = argv[0];
    const TCHAR *sep = _tcsrchrs(argv0, '/', '\\');
    TCHAR *dir = _tcsdup(_T(""));
    const TCHAR *basename = argv0;
    if (sep) {
        dir = _tcsdup(argv0);
        dir[sep + 1 - argv0] = '\0';
        basename = sep + 1;
    }
#ifdef _WIN32
    TCHAR module_path[8192];
    GetModuleFileName(NULL, module_path, sizeof(module_path)/sizeof(module_path[0]));
    TCHAR *sep2 = _tcsrchr(module_path, '\\');
    if (sep2) {
        sep2[1] = '\0';
        dir = _tcsdup(module_path);
    }
#endif
    basename = _tcsdup(basename);
    TCHAR *period = _tcschr(basename, '.');
    if (period)
        *period = '\0';
    TCHAR *dash = _tcsrchr(basename, '-');
    const TCHAR *target = basename;
    const TCHAR *exe = basename;
    if (dash) {
        *dash = '\0';
        exe = dash + 1;
    } else {
        target = _T(DEFAULT_TARGET);
    }
    TCHAR *arch = _tcsdup(target);
    dash = _tcschr(arch, '-');
    if (dash)
        *dash = '\0';

    int max_arg = argc + 20;
    const TCHAR **exec_argv = malloc(max_arg * sizeof(*exec_argv));
    int arg = 0;
    if (getenv("CCACHE"))
        exec_argv[arg++] = _T("ccache");
    exec_argv[arg++] = concat(dir, _T(CLANG));

    // If changing this wrapper, change clang-target-wrapper.sh accordingly.
    if (!_tcscmp(exe, _T("clang++")) || !_tcscmp(exe, _T("g++")) || !_tcscmp(exe, _T("c++")))
        exec_argv[arg++] = _T("--driver-mode=g++");

    if (!_tcscmp(arch, _T("i686"))) {
        // Dwarf is the default for i686, but libunwind sometimes fails to
        // to unwind correctly on i686. The issue can be reproduced with
        // test/exception-locale.cpp. The issue might be related to
        // DW_CFA_GNU_args_size, since it goes away if building
        // libunwind/libcxxabi/libcxx and the test example with
        // -mstack-alignment=16 -mstackrealign. (libunwind SVN r337312 fixed
        // some handling relating to this dwarf opcode, which made
        // test/hello-exception.cpp work properly, but apparently there are
        // still issues with it).
        exec_argv[arg++] = _T("-fsjlj-exceptions");
    } else if (!_tcscmp(arch, _T("x86_64"))) {
        // SEH is the default here.
    } else if (!_tcscmp(arch, _T("armv7"))) {
        // Dwarf is the default here.
    } else if (!_tcscmp(arch, _T("aarch64"))) {
        // Dwarf is the default here.
    }

    exec_argv[arg++] = _T("-target");
    exec_argv[arg++] = target;
    exec_argv[arg++] = _T("-rtlib=compiler-rt");
    exec_argv[arg++] = _T("-stdlib=libc++");
    exec_argv[arg++] = _T("-fuse-ld=lld");
    exec_argv[arg++] = _T("-fuse-cxa-atexit");
    exec_argv[arg++] = _T("-Qunused-arguments");

    for (int i = 1; i < argc; i++)
        exec_argv[arg++] = escape(argv[i]);

    exec_argv[arg] = NULL;
    if (arg > max_arg) {
        fprintf(stderr, "Too many options added\n");
        abort();
    }

#ifdef _WIN32
    int ret = _tspawnvp(_P_WAIT, exec_argv[0], exec_argv);
    if (ret == -1) {
        _tperror(exec_argv[0]);
        return 1;
    }
    return ret;
#else
    // On unix, exec() runs the target executable within this same process,
    // making the return code propagate implicitly.
    // Windows doesn't have such mechanisms, and the exec() family of functions
    // makes the calling process exit immediately and always returning
    // a zero return. This doesn't work for our case where we need the
    // return code propagated.
    _texecvp(exec_argv[0], EXECVP_CAST exec_argv);

    _tperror(exec_argv[0]);
    return 1;
#endif
}
