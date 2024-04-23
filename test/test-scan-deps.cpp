/*
 * Copyright (c) 2024 Martin Storsjo
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

// Test that clang-scan-deps can locate c++ standard library headers
#include <version>

// Test that we have set the expected architecture defines.
#if defined(__x86_64__)
#ifndef EXPECT_x86_64
#include <intentionally-missing-header>
#endif
#elif defined(__i386__)
#ifndef EXPECT_i686
#include <intentionally-missing-header>
#endif
#elif defined(__aarch64__)
#ifndef EXPECT_aarch64
#include <intentionally-missing-header>
#endif
#elif defined(__arm__)
#ifndef EXPECT_armv7
#include <intentionally-missing-header>
#endif
#endif
