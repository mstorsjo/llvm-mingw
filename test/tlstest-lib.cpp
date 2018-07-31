#define WIN32_LEAN_AND_MEAN
#include <stdio.h>
#include <windows.h>
#include <stdlib.h>

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

Hello lib_h("lib global");
static thread_local Hello lib_tls_h("lib global tls");

static void lib_atexit(void) {
    fprintf(stderr, "lib_atexit\n");
}

static class SetAtexit {
public:
    SetAtexit() {
        atexit(lib_atexit);
    }
} sa;

extern "C" void __declspec(dllexport) func(void) {
    fprintf(stderr, "func\n");
    static thread_local Hello h2("lib local tls");
    fprintf(stderr, "func end, thread %d\n", lib_tls_h.thread);
}
