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
#define _tcsncmp strncmp
#define _tperror perror
#define _texecvp execvp
#define _tmain main
#define _ftprintf fprintf
#define _vftprintf vfprintf
#define _tunlink unlink
#define EXECVP_CAST (char **)
#endif

#ifdef _UNICODE
#define TS "%ls"
#else
#define TS "%s"
#endif

#ifdef _WIN32
static inline TCHAR *escape(const TCHAR *str) {
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
}

static inline int _tspawnvp_escape(int mode, const TCHAR *filename, const TCHAR * const *argv) {
    int num_args = 0;
    while (argv[num_args])
        num_args++;
    const TCHAR **escaped_argv = malloc((num_args + 1) * sizeof(*escaped_argv));
    for (int i = 0; argv[i]; i++)
        escaped_argv[i] = escape(argv[i]);
    escaped_argv[num_args] = NULL;
    return _tspawnvp(mode, filename, escaped_argv);
}
#endif

static inline TCHAR *concat(const TCHAR *prefix, const TCHAR *suffix) {
    int prefixlen = _tcslen(prefix);
    int suffixlen = _tcslen(suffix);
    TCHAR *buf = malloc((prefixlen + suffixlen + 1) * sizeof(*buf));
    _tcscpy(buf, prefix);
    _tcscpy(buf + prefixlen, suffix);
    return buf;
}

static inline TCHAR *_tcsrchrs(const TCHAR *str, TCHAR char1, TCHAR char2) {
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

static inline void split_argv(const TCHAR *argv0, const TCHAR **dir_ptr, const TCHAR **basename_ptr, const TCHAR **target_ptr, const TCHAR **exe_ptr) {
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
    TCHAR *target = _tcsdup(basename);
    TCHAR *dash = _tcsrchr(target, '-');
    const TCHAR *exe = basename;
    if (dash) {
        *dash = '\0';
        exe = dash + 1;
    } else {
        target = NULL;
    }

    if (dir_ptr)
        *dir_ptr = dir;
    if (basename_ptr)
        *basename_ptr = basename;
    if (target_ptr)
        *target_ptr = target;
    if (exe_ptr)
        *exe_ptr = exe;
}

static inline int run_final(const TCHAR *executable, const TCHAR *const *argv) {
#ifdef _WIN32
    int ret = _tspawnvp_escape(_P_WAIT, executable, argv);
    if (ret == -1) {
        _tperror(executable);
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
    _texecvp(executable, EXECVP_CAST argv);

    _tperror(executable);
    return 1;
#endif
}
