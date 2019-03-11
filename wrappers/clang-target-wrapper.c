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

#ifdef _UNICODE
#define TS "%ls"
#else
#define TS "%s"
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

#ifdef _WIN32
static int filter_line = 0, last_char = '\n';
static void filter_stderr(char *buf, int n) {
    // Filter the stderr output from "-v" to rewrite paths from backslash
    // to forward slash form. libtool parses the output of "-v" and can't
    // handle the backslash form of paths. A proper upstream solution has
    // been discussed at https://reviews.llvm.org/D53066 but hasn't been
    // finished yet.
    int out = 0;
    int last = last_char;
    for (int i = 0; i < n; i++) {
        TCHAR cur = buf[i];
        // All lines that contain command lines or paths currently start
        // with a space.
        if (last == '\n') {
            filter_line = cur == ' ';
}
        if (filter_line) {
            if (cur == '"') {
                // Do nothing; skip the quotes. This assumes that after
                // converting backslashes to forward slashes, there's nothing
                // else (e.g. spaces) that needs quoting. libtool would
                // probably not handle that anyway, but this would break
                // a more capable caller which also parses the output of "-v".
            } else if (cur == '\\') {
                // Convert backslashes to forward slashes. Quoted backslashes
                // are doubled, so just output every other one. We don't really
                // keep track of whether we're in a quoted context though.
                if (last != '\\') {
                    buf[out++] = '/';
                } else {
                    // Last output char was a backslash converted into a
                    // forward slash. Ignore this one, but handle the next
                    // one in case there's more.
                    last = ' ';
                }
            } else {
                buf[out++] = cur;
            }
        } else {
            buf[out++] = cur;
        }

        last = cur;
    }
    last_char = last;
    fwrite(buf, 1, out, stderr);
}

static int exec_filtered(const TCHAR **argv) {
    int len = 1;
    for (int i = 0; argv[i]; i++)
        len += _tcslen(argv[i]) + 1;
    TCHAR *cmdline = malloc(len * sizeof(*cmdline));
    int pos = 0;
    // On Windows, the arguments are already quoted and escaped properly.
    for (int i = 0; argv[i]; i++) {
        _tcscpy(&cmdline[pos], argv[i]);
        pos += _tcslen(argv[i]);
        cmdline[pos++] = ' ';
    }
    if (pos > 0)
        pos--;
    cmdline[pos] = '\0';

    STARTUPINFO si = { 0 };
    PROCESS_INFORMATION pi = { 0 };
    HANDLE pipe_read = NULL, pipe_write = NULL;
    SECURITY_ATTRIBUTES sa = { 0 };
    sa.nLength = sizeof(sa);
    sa.bInheritHandle = TRUE;
    CreatePipe(&pipe_read, &pipe_write, &sa, 0);
    si.cb = sizeof(si);
    si.dwFlags = STARTF_USESTDHANDLES;
    si.hStdInput = GetStdHandle(STD_INPUT_HANDLE);
    si.hStdOutput = GetStdHandle(STD_OUTPUT_HANDLE);
    si.hStdError = pipe_write;
    if (!CreateProcess(NULL, cmdline, NULL, NULL, /* bInheritHandles */ TRUE,
                      0, NULL, NULL, &si, &pi)) {
        DWORD err = GetLastError();
        TCHAR *errbuf;
        FormatMessage(FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
                      NULL, err, MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
                      (LPTSTR) &errbuf, 0, NULL);
        _ftprintf(stderr, _T("Unable to execute: "TS": "TS"\n"), cmdline, errbuf);
        LocalFree(errbuf);
        CloseHandle(pipe_read);
        CloseHandle(pipe_write);
        free(cmdline);
        return 1;
    }

    CloseHandle(pipe_write);
    char stderr_buf[8192];
    DWORD n;
    while (ReadFile(pipe_read, stderr_buf, sizeof(stderr_buf), &n, NULL))
        filter_stderr(stderr_buf, n);
    CloseHandle(pipe_read);

    WaitForSingleObject(pi.hProcess, INFINITE);
    DWORD exit_code = 1;
    GetExitCodeProcess(pi.hProcess, &exit_code);

    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);
    free(cmdline);
    return exit_code;
}
#endif

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
        // Dwarf is the default for i686, but there are a few issues with
        // dwarf unwinding in code generated for i686, see
        // https://bugs.llvm.org/show_bug.cgi?id=40012 and
        // https://bugs.llvm.org/show_bug.cgi?id=40322.
        exec_argv[arg++] = _T("-fsjlj-exceptions");
    } else if (!_tcscmp(arch, _T("x86_64"))) {
        // SEH is the default here.
    } else if (!_tcscmp(arch, _T("armv7"))) {
        // Dwarf is the default here.
    } else if (!_tcscmp(arch, _T("aarch64"))) {
        // Dwarf is the default here.
    }

    if (target_os && !_tcscmp(target_os, _T("mingw32uwp"))) {
        // the UWP target is for Windows 10
        exec_argv[arg++] = _T("-D_WIN32_WINNT=0x0A00 -DWINVER=0x0A00");
        // the UWP target can only use Windows Store APIs
        exec_argv[arg++] = _T("-DWINAPI_FAMILY=WINAPI_FAMILY_APP");
        // the Windows Store API only supports Windows Unicode (some rare ANSI ones are available)
        exec_argv[arg++] = _T("-DUNICODE");
        // add the minimum runtime to use for UWP targets
        exec_argv[arg++] = _T("-Wl,-lmincore");
        // This requires that the default crt is ucrt.
        exec_argv[arg++] = _T("-Wl,-lvcruntime140_app");
    } else if (target_os && !_tcscmp(target_os, _T("mingw32winrt"))) {
        // the WinRT target is for Windows 8.1
        exec_argv[arg++] = _T("-D_WIN32_WINNT=0x0603 -DWINVER=0x0603");
        // the WinRT target can only use Windows Store APIs
        exec_argv[arg++] = _T("-DWINAPI_FAMILY=WINAPI_FAMILY_APP");
        // the Windows Store API only supports Windows Unicode (some rare ANSI ones are available)
        exec_argv[arg++] = _T("-DUNICODE");
        // add the minimum runtime to use for WinRT targets
        exec_argv[arg++] = _T("-Wl,-lmincore");
        exec_argv[arg++] = _T("-Wl,-lmsvcr120_app");
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
    // If the command line contains the "-v" argument, filter the stderr
    // output to rewrite paths from backslash to forward slash form.
    // libtool parses the output of "-v" and can't handle the backslash
    // form of paths. A proper upstream solution has been discussed at
    // https://reviews.llvm.org/D53066 but hasn't been finished yet.
    for (int i = 1; i < argc; i++)
        if (!_tcscmp(argv[i], _T("-v")))
            return exec_filtered(exec_argv);

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
