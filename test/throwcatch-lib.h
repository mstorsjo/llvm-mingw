/*
 * Copyright (c) 2021 Martin Storsjo
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

#ifndef THROWCATCH_LIB_H
#define THROWCATCH_LIB_H

#include <exception>
#include <string>

class FirstException : public std::exception {
public:
    FirstException(const char *s) : str(s) {}

    const char *what() const noexcept override {
        return str.c_str();
    }

private:
    std::string str;
};

class SecondException : public std::exception {
public:
    SecondException(const char *s) : str(s) {}

    const char *what() const noexcept override {
        return str.c_str();
    }

private:
    std::string str;
};

void libFunc(int param);

#endif
