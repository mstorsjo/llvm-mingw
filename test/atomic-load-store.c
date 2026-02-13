/*
 * Copyright (c) 2026 Martin Storsjo
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

#include <stdatomic.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#ifdef __SIZEOF_INT128__
#define TYPE __uint128_t
#else
#define TYPE uint64_t
#endif

_Atomic(TYPE) atomic_var;
TYPE regular_var;

int main(int argc, char **argv) {
    regular_var = 0x0123456789abcdef;
#ifdef __SIZEOF_INT128__
    regular_var <<= 64;
    regular_var |= 0xfedcba9876543210;
#endif
    memcpy(&atomic_var, &regular_var, sizeof(regular_var));
    regular_var = atomic_load(&atomic_var);
    if (memcmp(&atomic_var, &regular_var, sizeof(regular_var))) {
        printf("load failed\n");
        return 1;
    }
    atomic_store(&atomic_var, regular_var);
    if (memcmp(&atomic_var, &regular_var, sizeof(regular_var))) {
        printf("store failed\n");
        return 1;
    }
    return 0;
}
