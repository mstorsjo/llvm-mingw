/*
 * Copyright (c) 2022 Martin Storsjo
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

#if defined(__linux__) || defined(__MINGW32__)
#define _GNU_SOURCE
#endif

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

char buf[10];
char padding[10];

const char *ten_chars = "1234567890";
int ten = 10;
const char *eleven_chars = "1234567890!";
int eleven = 11;

const char *foo = "foo";
const char *barbar = "barbar";
const char *barbarr = "barbarr";
const char *barbarrr = "barbarrr";
int six = 6;
int seven = 7;
int eight = 8;

char hash = '#';

#if !defined(__GLIBC__) && !defined(__MINGW32__)
#define mempcpy memcpy
#endif

static void acceptable_use(void) {
    memcpy(buf, ten_chars, ten);
    memmove(buf, ten_chars, ten);
    mempcpy(buf, ten_chars, ten);
    memset(buf, hash, ten);

    // Test writing a full buffer without null termination.
    strncpy(buf, eleven_chars, ten);

    strcpy(buf, foo);
    strcat(buf, barbar);

    strcpy(buf, foo);
    // We copy a truncated amount from the source, and fit exactly in the
    // buffer.
    strncat(buf, barbarrr, six);
}

int main(int argc, char *argv[]) {
#ifndef _FORTIFY_SOURCE
    fprintf(stderr, "NOTE, this is built without _FORTIFY_SOURCE; the "
                    "checks will fail!\n");
#endif
    if (argc < 2) {
        acceptable_use();
        fprintf(stderr, "%s: A test tool for detecting buffer overflows.\n"
                        "Run this with an integer between 1 and 10 to test "
                        "various overflows that should be caught.\n", argv[0]);
        return 0;
    }
    switch (atoi(argv[1])) {
    default:
    case 1:
        memcpy(buf, eleven_chars, eleven);
        break;
    case 2:
        memmove(buf, eleven_chars, eleven);
        break;
    case 3:
        mempcpy(buf, eleven_chars, eleven);
        break;
    case 4:
        memset(buf, hash, eleven);
        break;
    case 5:
        // The contents of the string fits in the buffer, but the null
        // terminator doesn't.
        strcpy(buf, ten_chars);
        break;
    case 6:
        // The contents of the string doesn't fit in the buffer.
        strncpy(buf, eleven_chars, eleven);
        break;
    case 7:
        strcpy(buf, foo);
        // The contents of the string fits in the buffer, but the null
        // terminator doesn't.
        strcat(buf, barbarr);
        break;
    case 8:
        strcpy(buf, foo);
        // The contents of the string doesn't fit in the buffer.
        strcat(buf, barbarrr);
        break;
    case 9:
        strcpy(buf, foo);
        // We copy a truncated amount from the source, but the null terminator
        // doesn't fit in the buffer.
        strncat(buf, barbarrr, seven);
        break;
    case 10:
        strcpy(buf, foo);
        // The contents of the string doesn't fit in the buffer.
        strncat(buf, barbarrr, eight);
        break;
    }
    return 0;
}
