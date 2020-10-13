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

class RecurseClass {
public:
    RecurseClass(int v) : val(v) {
        printf("ctor %d\n", val);
    }
    ~RecurseClass() {
        printf("dtor %d\n", val);
    }
private:
    int val;
};

bool crash = false;

void recurse(int val) {
    RecurseClass obj(val);
    if (val == 0) {
        if (crash)
            *(volatile int*)NULL = 0x42;
        throw std::exception();
    }
    if (val == 5) {
        try {
            recurse(val - 1);
        } catch (std::exception& e) {
            printf("caught exception at %d\n", val);
        }
    } else {
        recurse(val - 1);
    }
    printf("finishing function recurse %d\n", val);
}

int main(int argc, char* argv[]) {
    if (argc > 1 && !strcmp(argv[1], "-crash")) {
        /* This mode is useful for testing backtraces in a debugger. */
        crash = true;
        printf("Crashing instead of throwing an exception\n");
    }
    recurse(10);
    return 0;
}
