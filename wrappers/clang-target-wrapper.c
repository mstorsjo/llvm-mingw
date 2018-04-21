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

#include "native-wrapper.h"

#ifndef CLANG
#define CLANG "clang"
#endif
#ifndef DEFAULT_TARGET
#define DEFAULT_TARGET "x86_64-w64-mingw32"
#endif

int _tmain(int argc, TCHAR* argv[]) {
    const TCHAR *dir;
    const TCHAR *target;
    const TCHAR *exe;
    split_argv(argv[0], &dir, NULL, &target, &exe);
    if (!target)
        target = _T(DEFAULT_TARGET);
    TCHAR *arch = _tcsdup(target);
    TCHAR *dash = _tcschr(arch, '-');
    if (dash)
        *dash = '\0';
    TCHAR *target_os = _tcsrchr(target, '-');
    if (target_os)
        target_os++;

    // Check if trying to compile Ada; if we try to do this, invoking clang
    // would end up invoking <triplet>-gcc with the same arguments, which ends
    // up in an infinite recursion.
    for (int i = 1; i < argc - 1; i++) {
        if (!_tcscmp(argv[i], _T("-x")) && !_tcscmp(argv[i + 1], _T("ada"))) {
            fprintf(stderr, "Ada is not supported\n");
            return 1;
        }
    }

    int max_arg = argc + 18;
    const TCHAR **exec_argv = malloc((max_arg + 1) * sizeof(*exec_argv));
    int arg = 0;
    if (getenv("CCACHE"))
        exec_argv[arg++] = _T("ccache");
    exec_argv[arg++] = concat(dir, _T(CLANG));
    exec_argv[arg++] = _T("--start-no-unused-arguments");

    // If changing this wrapper, change clang-target-wrapper.sh accordingly.
    if (!_tcscmp(exe, _T("clang++")) || !_tcscmp(exe, _T("g++")) || !_tcscmp(exe, _T("c++")))
        exec_argv[arg++] = _T("--driver-mode=g++");
    else if (!_tcscmp(exe, _T("c99")))
        exec_argv[arg++] = _T("-std=c99");
    else if (!_tcscmp(exe, _T("c11")))
        exec_argv[arg++] = _T("-std=c11");

    if (target_os && !_tcscmp(target_os, _T("mingw32uwp"))) {
        // the UWP target is for Windows 10
        exec_argv[arg++] = _T("-D_WIN32_WINNT=0x0A00");
        exec_argv[arg++] = _T("-DWINVER=0x0A00");
        // the UWP target can only use Windows Store APIs
        exec_argv[arg++] = _T("-DWINAPI_FAMILY=WINAPI_FAMILY_APP");
        // the Windows Store API only supports Windows Unicode (some rare ANSI ones are available)
        exec_argv[arg++] = _T("-DUNICODE");
        // force the Universal C Runtime
        exec_argv[arg++] = _T("-D_UCRT");
    }

    exec_argv[arg++] = _T("--config");
    exec_argv[arg++] = concat(arch, _T("-w64-mingw32.cfg"));
    exec_argv[arg++] = _T("--end-no-unused-arguments");

    for (int i = 1; i < argc; i++)
        exec_argv[arg++] = argv[i];

    if (target_os && !_tcscmp(target_os, _T("mingw32uwp"))) {
        // Default linker flags; passed after any user specified -l options,
        // to let the user specified libraries take precedence over these.

        exec_argv[arg++] = _T("--start-no-unused-arguments");
        // add the minimum runtime to use for UWP targets
        exec_argv[arg++] = _T("-Wl,-lwindowsapp");
        // This still requires that the toolchain (in particular, libc++.a) has
        // been built targeting UCRT originally.
        exec_argv[arg++] = _T("-Wl,-lucrtapp");
        exec_argv[arg++] = _T("--end-no-unused-arguments");
    }

    exec_argv[arg] = NULL;
    if (arg > max_arg) {
        fprintf(stderr, "Too many options added\n");
        abort();
    }

    return run_final(exec_argv[0], exec_argv);
}
