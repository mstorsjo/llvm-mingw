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

#include <array>
#include <atomic>
#include <cstdint>
#include <iostream>
#include <numeric>

int retval = 0;

template <std::size_t size, std::size_t max_size>
void f() {
    using type_t = std::array<std::uint8_t, size>;
    type_t init;
    for (std::size_t i = 0; i < size; i++)
        init[i] = i;
    std::atomic<type_t> atom(init);
    bool match = atom.load() == init;
    std::cout << size << " byte atomic: " << (match ? "ok\n" : "FAILED\n");
    if (!match)
        retval = 1;
    if constexpr (size < max_size) {
        f<size + 1, max_size>();
    }
}

int main() {
    f<1, 32>();
    return retval;
}
