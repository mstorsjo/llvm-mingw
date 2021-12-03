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

#include <exception>
#include <stdio.h>
#include <string.h>
#include <thread>
#include <chrono>

class RecurseClass {
public:
    RecurseClass(int v) : val(v) {
        fprintf(stderr, "ctor %d\n", val);
        fflush(stderr);
    }
    ~RecurseClass() {
        fprintf(stderr, "dtor %d\n", val);
        fflush(stderr);
    }
private:
    int val;
};

bool crash = false;
bool breakpoint = false;
bool noop = false;
bool do_wait = false;

void done() {
}

void recurse(int val) {
    RecurseClass obj(val);
    if (val == 0) {
        if (crash)
            *(volatile int*)NULL = 0x42;
#ifdef _WIN32
        else if (breakpoint)
            __debugbreak();
#endif
        else if (noop)
            done();
        else
            throw std::exception();
    } else if (val == 5) {
        try {
            recurse(val - 1);
        } catch (std::exception& e) {
            fprintf(stderr, "caught exception at %d\n", val);
            fflush(stderr);
        }
    } else {
        recurse(val - 1);
    }
    fprintf(stderr, "finishing function recurse %d\n", val);
    fflush(stderr);
}

int main(int argc, char* argv[]) {
    for (int i = 1; i < argc; i++) {
        /* These modes are useful for testing backtraces in a debugger. */
        if (!strcmp(argv[i], "-crash")) {
            crash = true;
            fprintf(stderr, "Crashing instead of throwing an exception\n");
        } else if (!strcmp(argv[i], "-breakpoint")) {
#ifdef _WIN32
            breakpoint = true;
            fprintf(stderr, "Triggering breakpoint instead of throwing an exception\n");
#else
            fprintf(stderr, "Programmatic breakpoints not supported\n");
#endif
        } else if (!strcmp(argv[i], "-noop")) {
            noop = true;
            fprintf(stderr, "Calling the function 'done' when recursion stops\n");
        } else if (!strcmp(argv[i], "-wait")) {
            do_wait = true;
            fprintf(stderr, "Waiting before exiting\n");
        }
    }
    recurse(10);
    if (do_wait) {
        fprintf(stderr, "Waiting\n");
        using namespace std::chrono_literals;
        std::this_thread::sleep_for(10s);
        fprintf(stderr, "Exiting\n");
    }
    return 0;
}
