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

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <process.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

HANDLE event1, event2, event3;
void (*func)(void);

class Hello {
public:
    Hello(const char* s) {
        str = s;
        thread = GetCurrentThreadId();
        fprintf(stderr, "%s ctor on thread %d\n", str, thread);
    }
    ~Hello() {
        fprintf(stderr, "%s dtor from thread %d, now on %d\n", str, thread, (int) GetCurrentThreadId());
    }
    const char* str;
    int thread;
};

unsigned __stdcall threadfunc(void *arg) {
    HANDLE event = (HANDLE) arg;
    int threadId = GetCurrentThreadId();
    fprintf(stderr, "threadfunc thread %d\n", threadId);
    static thread_local Hello main_h("main local tls");
    SetEvent(event3);
    WaitForSingleObject(event, INFINITE);
    fprintf(stderr, "thread %d calling func\n", threadId);
    if (func)
        func();
    SetEvent(event3);
    WaitForSingleObject(event, INFINITE);

    fprintf(stderr, "thread %d finishing\n", threadId);
    return 0;
}

static Hello main_h("main global");

static void atexit_func(void) {
    fprintf(stderr, "main atexit_func\n");
}

int main(int argc, char* argv[]) {
    atexit(atexit_func);
    fprintf(stderr, "main\n");
    event1 = CreateEvent(NULL, FALSE, FALSE, NULL);
    event2 = CreateEvent(NULL, FALSE, FALSE, NULL);
    event3 = CreateEvent(NULL, FALSE, FALSE, NULL);
    fprintf(stderr, "main, starting thread1\n");
    HANDLE thread1 = (HANDLE)_beginthreadex(NULL, 0, threadfunc, event1, 0, NULL);
    WaitForSingleObject(event3, INFINITE);
    fprintf(stderr, "main, thread1 started\n");
    fprintf(stderr, "LoadLibrary tlstest-lib.dll\n");
    HMODULE h = LoadLibrary("tlstest-lib.dll");
    fprintf(stderr, "LoadLibrary tlstest-lib.dll ret %p\n", h);
    if (!h) {
        fprintf(stderr, "Unable to load tlstest-lib.dll\n");
        return 1;
    }
    func = (void (*)(void)) GetProcAddress(h, "func");
    fprintf(stderr, "main, got func address, calling it\n");
    if (func)
        func();

    fprintf(stderr, "main, starting thread2\n");
    HANDLE thread2 = (HANDLE)_beginthreadex(NULL, 0, threadfunc, event2, 0, NULL);
    WaitForSingleObject(event3, INFINITE);
    fprintf(stderr, "main, thread2 started\n");

    SetEvent(event1);
    WaitForSingleObject(event3, INFINITE);
    fprintf(stderr, "main, thread1 work done\n");

    SetEvent(event2);
    WaitForSingleObject(event3, INFINITE);
    fprintf(stderr, "main, thread2 work done\n");

    SetEvent(event1);
    WaitForSingleObject(thread1, INFINITE);
    fprintf(stderr, "main, thread1 joined\n");

    fprintf(stderr, "FreeLibrary\n");
    FreeLibrary(h);
    fprintf(stderr, "FreeLibrary done\n");

    SetEvent(event2);
    WaitForSingleObject(thread2, INFINITE);
    fprintf(stderr, "main, thread2 joined\n");
    static thread_local Hello main_h("main local tls");
    atexit(atexit_func);
    fprintf(stderr, "main done\n");
    return 0;
}
