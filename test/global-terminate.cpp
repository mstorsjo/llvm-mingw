/*
 * Copyright (c) 2020 Liu Hao
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
#include <stdlib.h>

void whoa() {
    ::puts("whoa!");  // expected output
    ::exit(0);
}

int main(int argc, char *argv[]) {
#if defined(__aarch64__) && defined(__clang__) && __clang_major__ < 12
    // This test succeeds with latest clang (since 20f7773bb4bb458, Sept 2020,
    // on the clang 12.0 branch), but fails before that.
    return 0;
#else
    ::std::set_terminate(whoa);
    throw 42;
#endif
}
