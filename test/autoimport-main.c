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

#include "autoimport-lib.h"

int *ptr = &var;

int *arrayptr = &array[3];

int main(int argc, char *argv[]) {
    setVar(42);
    if (var != 42) return 1;
    var++;
    if (getVar() != 43) return 1;
    (*ptr)++;
    if (getVar() != 44) return 1;

    setArray(3, 100);
    if (array[3] != 100) return 1;
    if (*arrayptr != 100) return 1;
    array[3]++;
    if (*arrayptr != 101) return 1;
    if (getArray(3) != 101) return 1;
    (*arrayptr)++;
    if (getArray(3) != 102) return 1;
    return 0;
}
