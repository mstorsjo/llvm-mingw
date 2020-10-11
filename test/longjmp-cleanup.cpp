/*
 * Copyright (c) 2020 Martin Storsjo
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

#include <stdio.h>
#include <setjmp.h>

jmp_buf jmp;

class RecurseClass {
public:
    RecurseClass(int v) : val(v) {
        fprintf(stderr, "ctor %d\n", val);
    }
    ~RecurseClass() {
        fprintf(stderr, "dtor %d\n", val);
    }
private:
    int val;
};

void recurse(int val) {
    RecurseClass obj(val);
    if (val == 0) {
          longjmp(jmp, 1);
    }
    if (val == 5) {
        if (!setjmp(jmp))
            recurse(val - 1);
        else
            fprintf(stderr, "returned from setjmp\n");
    } else {
        recurse(val - 1);
    }
    fprintf(stderr, "finishing function recurse %d\n", val);
}

int main(int argc, char* argv[]) {
    recurse(10);
    return 0;
}
