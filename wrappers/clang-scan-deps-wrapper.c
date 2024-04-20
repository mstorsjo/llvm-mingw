/*
 * Copyright (c) 2024 Martin Storsjo
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

#include "native-wrapper.h"

#ifndef DEFAULT_TARGET
#define DEFAULT_TARGET "x86_64-w64-mingw32"
#endif

int _tmain(int argc, TCHAR *argv[]) {
    const TCHAR *dir;
    split_argv(argv[0], &dir, NULL, NULL, NULL);

    int max_arg = argc + 3;
    const TCHAR **exec_argv = malloc((max_arg + 1) * sizeof(*exec_argv));
    int arg = 0;
    exec_argv[arg++] = concat(dir, _T("clang-scan-deps"));

    // If changing this wrapper, change clang-scan-deps-wrapper.sh accordingly.
    int i = 1;
    int got_flags = 0;
    TCHAR *cmd_exe = NULL;
    for (; i < argc; i++) {
        if (got_flags) {
            cmd_exe = _tcsdup(argv[i]);
            exec_argv[arg++] = argv[i];
            i++;
            break;
        } else if (!_tcscmp(argv[i], _T("--"))) {
            got_flags = 1;
            exec_argv[arg++] = argv[i];
        } else {
            exec_argv[arg++] = argv[i];
        }
    }

    if (cmd_exe) {
        // If cmd_exe is a <triple>-<exe> style command, prefer the
        // target triple from there, rather than from what we might have
        // had in our name.
        TCHAR *sep = _tcsrchrs(cmd_exe, '/', '\\');
        if (sep)
            cmd_exe = sep + 1;
        sep = _tcsrchr(cmd_exe, '.');
        if (sep)
            *sep = '\0';
        TCHAR *dash = _tcsrchr(cmd_exe, '-');
        const TCHAR *target = NULL;
        if (dash) {
            *dash = '\0';
            const TCHAR *cmd_exe_suffix = dash + 1;
            if (!_tcscmp(cmd_exe_suffix, _T("clang")) ||
                !_tcscmp(cmd_exe_suffix, _T("clang++")) ||
                !_tcscmp(cmd_exe_suffix, _T("gcc")) ||
                !_tcscmp(cmd_exe_suffix, _T("g++")) ||
                !_tcscmp(cmd_exe_suffix, _T("c++")) ||
                !_tcscmp(cmd_exe_suffix, _T("as")) ||
                !_tcscmp(cmd_exe_suffix, _T("cc")) ||
                !_tcscmp(cmd_exe_suffix, _T("c99")) ||
                !_tcscmp(cmd_exe_suffix, _T("c11"))) {
                target = cmd_exe;
            }
        }
#ifdef _WIN32
        // On Windows, we want to set our default target even if no target
        // was found in cmd_exe, as we want to support running with a foreign
        // clang-scan-deps-real.exe binary, that could have any default.
        if (!target)
            target = _T(DEFAULT_TARGET);
#endif

        if (target) {
            // If we did find a cmd_exe and have figured out a target, add
            // -target after cmd_exe.
            exec_argv[arg++] = _T("-target");
            exec_argv[arg++] = target;
            exec_argv[arg++] = _T("-stdlib=libc++");
        }
    }

    for (; i < argc; i++)
        exec_argv[arg++] = argv[i];

    exec_argv[arg] = NULL;
    if (arg > max_arg) {
        fprintf(stderr, "Too many options added\n");
        abort();
    }

    return run_final(exec_argv[0], exec_argv);
}
