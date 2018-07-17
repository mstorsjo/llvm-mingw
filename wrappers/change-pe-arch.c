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

#include <stdio.h>
#include <stdint.h>
#include <string.h>

#define IMAGE_DOS_SIGNATURE 0x5A4D
#define IMAGE_NT_SIGNATURE  0x00004550

#define IMAGE_FILE_MACHINE_AMD64 0x8664
#define IMAGE_FILE_MACHINE_ARMNT  0x1C4
#define IMAGE_FILE_MACHINE_ARM64 0xAA64
#define IMAGE_FILE_MACHINE_I386   0x14C

static uint16_t readUint16(FILE *f) {
    uint8_t buf[2];
    if (fread(buf, 1, 2, f) != 2)
        return -1;
    return buf[0] | (buf[1] << 8);
}

static uint32_t readUint32(FILE *f) {
    uint8_t buf[4];
    if (fread(buf, 1, 4, f) != 4)
        return -1;
    return buf[0] | (buf[1] << 8) | (buf[2] << 16) | (buf[3] << 24);
}

static void writeUint16(FILE *f, uint16_t val) {
    uint8_t buf[2];
    buf[0] =  val       & 0xff;
    buf[1] = (val >> 8) & 0xff;
    if (fwrite(buf, 1, 2, f) != 2)
        perror("fwrite");
}

static void writeUint32(FILE *f, uint32_t val) {
    uint8_t buf[4];
    buf[0] =  val        & 0xff;
    buf[1] = (val >>  8) & 0xff;
    buf[2] = (val >> 16) & 0xff;
    buf[3] = (val >> 24) & 0xff;
    if (fwrite(buf, 1, 4, f) != 4)
        perror("fwrite");
}

static uint16_t archToInt(const char *str) {
    if (!strcmp(str, "i686"))
        return IMAGE_FILE_MACHINE_I386;
    else if (!strcmp(str, "x86_64"))
        return IMAGE_FILE_MACHINE_AMD64;
    else if (!strcmp(str, "armv7"))
        return IMAGE_FILE_MACHINE_ARMNT;
    else if (!strcmp(str, "aarch64"))
        return IMAGE_FILE_MACHINE_ARM64;
    fprintf(stderr, "Unknown architecture %s\n", str);
    return 0;
}

static int is64Bit(uint16_t arch) {
    switch (arch) {
    case IMAGE_FILE_MACHINE_AMD64:
    case IMAGE_FILE_MACHINE_ARM64:
        return 1;
    default:
        return 0;
    }
}

void help(const char *argv0) {
    printf("%s [-check] [-from arch] [-to arch] file\n", argv0);
}

int main(int argc, char *argv[]) {
    int check = 0;
    uint16_t from = 0, to = 0;
    int i;
    const char *filename = NULL;
    FILE *f;
    uint32_t offset;
    for (i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "-check")) {
            check = 1;
        } else if (!strcmp(argv[i], "-from") && i + 1 < argc) {
            from = archToInt(argv[++i]);
        } else if (!strcmp(argv[i], "-to") && i + 1 < argc) {
            to = archToInt(argv[++i]);
        } else if (!filename) {
            filename = argv[i];
        } else {
            help(argv[0]);
            return 1;
        }
    }
    if ((!check && (!from || !to)) || !filename) {
        help(argv[0]);
        return 1;
    }
    if (!check && is64Bit(from) != is64Bit(to)) {
        fprintf(stderr, "Mismatched atchitecture bitness\n");
        return 1;
    }
    f = fopen(filename, "r+b");
    if (!f) {
        perror(filename);
        return 1;
    }
    if (readUint16(f) != IMAGE_DOS_SIGNATURE) {
        if (!check)
            fprintf(stderr, "Incorrect DOS header signature\n");
        goto fail;
    }
    if (fseek(f, 0x3c, SEEK_SET) == -1) { // offsetof(IMAGE_DOS_HEADER, e_lfanew)
        if (!check)
            fprintf(stderr, "Unable to seek\n");
        goto fail;
    }
    offset = readUint32(f);
    if (fseek(f, offset, SEEK_SET) == -1) {
        if (!check)
            fprintf(stderr, "Unable to seek\n");
        goto fail;
    }
    if (readUint32(f) != IMAGE_NT_SIGNATURE) {
        if (!check)
            fprintf(stderr, "Incorrect NT header signature\n");
        goto fail;
    }
    if (check)
        goto done;
    if (readUint16(f) != from) {
        fprintf(stderr, "Unexpected architecture\n");
        goto fail;
    }
    fseek(f, -2, SEEK_CUR);
    writeUint16(f, to);
    if (fseek(f, offset + 0x58, SEEK_SET) == -1) { // offsetof(IMAGE_NT_HEADERS, OptionalHeader.CheckSum)
        fprintf(stderr, "Unable to seek\n");
        goto fail;
    }
    writeUint32(f, 0);
done:
    fclose(f);
    return 0;
fail:
    fclose(f);
    return 1;
}
