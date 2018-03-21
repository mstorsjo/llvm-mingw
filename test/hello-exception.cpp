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

#include <iostream>
#include <stdio.h>

class Hello {
public:
    Hello() {
        printf("Hello ctor\n");
    }
    ~Hello() {
        printf("Hello dtor\n");
    }
};

Hello global_h;

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

void recurse(int val) {
    RecurseClass obj(val);
    if (val == 0) {
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
    std::cout<<"Hello world C++"<<std::endl;
    recurse(10);
    return 0;
}
