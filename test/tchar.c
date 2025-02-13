/*
 * Copyright (c) 2025 Martin Storsjo
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
#include <tchar.h>

int _tmain(int argc, TCHAR* argv[]) {
    _tprintf(_T("_tprintf\n"));
    _ftprintf(stdout, _T("_ftprintf\n"));

    TCHAR buffer[100];
    _stprintf(buffer, _T("foo %d"), 123);
    if (_tcscmp(buffer, _T("foo 123"))) {
        _tprintf(_T("incorrect _stprintf output\n"));
        return 1;
    }
    _stprintf(buffer, _T("str %s"), _T("arg"));
    if (_tcscmp(buffer, _T("str arg"))) {
        _tprintf(_T("incorrect _stprintf output for %%s\n"));
        return 1;
    }

    int val;
    if (_stscanf(_T("123"), _T("%d"), &val) != 1 || val != 123) {
        _tprintf(_T("incorrect _stscanf output\n"));
        return 1;
    }

    return 0;
}
