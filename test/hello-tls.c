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

#include <windows.h>
#include <stdio.h>
#include <process.h>
#include <stdint.h>

#if defined(_MSC_VER)
static __declspec(thread) int tlsvar = 1;
#else
static __thread int tlsvar = 1;
#endif

static unsigned __stdcall threadfunc(void* arg) {
    int id = (int)(intptr_t)arg;
    printf("thread %d, tlsvar %p initially %d\n", id, &tlsvar, tlsvar);
    tlsvar = id + 100;
    for (int i = 0; i < 4; i++) {
        printf("thread %d, tlsvar %p %d\n", id, &tlsvar, tlsvar);
        tlsvar += 10;
        Sleep(500);
    }
    return 0;
}

int main(int argc, char* argv[]) {
    HANDLE threads[3];

    for (int i = 0; i < 3; i++) {
        printf("mainthread, tlsvar %p %d\n", &tlsvar, tlsvar);
        tlsvar += 10;
        threads[i] = (HANDLE)_beginthreadex(NULL, 0, threadfunc, (void*)(intptr_t) (i + 1), 0, NULL);
        Sleep(350);
    }
    for (int i = 0; i < 3; i++) {
        WaitForSingleObject(threads[i], INFINITE);
        CloseHandle(threads[i]);
    }
    return 0;
}
