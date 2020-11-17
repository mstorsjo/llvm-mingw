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

#ifdef __linux__
#define _GNU_SOURCE
#endif
#include <stdio.h>
#include <math.h>
#include <string.h>
#include <stdlib.h>
#include <fenv.h>
#include <inttypes.h>
#include <stdarg.h>
#include <errno.h>
#include <limits.h>
#include <float.h>
#ifdef _WIN32
#include <windows.h>
#endif

#ifndef _WIN32
extern char **environ;
#endif

#ifdef _WIN32
static void invalid_parameter(const wchar_t *expression, const wchar_t *function, const wchar_t *file, unsigned int line, uintptr_t pReserved) {
}
#endif

int tests = 0, fails = 0;
const char *context = "";

#define TEST(x) do { \
        tests++; \
        if (!(x)) { \
            fails++; \
            printf("%s:%d: %s\"%s\" failed\n", __FILE__, __LINE__, context, #x); \
        } \
    } while (0)

#define TEST_STR(x, expect) do { \
        tests++; \
        if (strcmp((x), (expect))) { \
            fails++; \
            printf("%s:%d: %sexpected \"%s\", got \"%s\"\n", __FILE__, __LINE__, context, (expect), (x)); \
        } \
    } while (0)

#define TEST_FLT(x, expect) do { \
        tests++; \
        if ((x) != (expect)) { \
            fails++; \
            printf("%s:%d: %s%s failed, expected %f, got %f\n", __FILE__, __LINE__, context, #x, (double)(expect), (double)(x)); \
        } \
    } while (0)

#define TEST_FLT_EXPR(x, expr) do { \
        tests++; \
        if (!(expr)) { \
            fails++; \
            printf("%s:%d: %s%s failed, got %f\n", __FILE__, __LINE__, context, #expr, (double)(x)); \
        } \
    } while (0)

#define TEST_FLT_NAN_ANY(x) do { \
        tests++; \
        if (!isnan(x)) { \
            fails++; \
            printf("%s:%d: %s%s failed, expected any NAN, got %f\n", __FILE__, __LINE__, context, #x, (double)(x)); \
        } \
    } while (0)

// Use TEST_FLT_NAN with F(NAN) or -F(NAN) as the expect parameter.
// On Glibc, F(-NAN), i.e. strtod("-NAN", NULL), returns a positive NAN.
// On MSVC, the NAN literal is negative, but strtod("NAN", NULL) returns a
// positive one.
#define TEST_FLT_NAN(x, expect) do { \
        tests++; \
        long double val = (x); \
        long double expval = (expect); \
        if (!isnan(val) || !!signbit(val) != !!signbit(expval)) { \
            fails++; \
            printf("%s:%d: %s%s failed, expected %f, got %f\n", __FILE__, __LINE__, context, #x, (double)expval, (double)val); \
        } \
    } while (0)

#define TEST_FLT_ACCURACY(x, expect, accuracy) do { \
        long double val = (x); \
        long double diff = fabsl(val - (expect)); \
        tests++; \
        if (diff <= (accuracy)) { \
            /* All ok, not NAN */ \
        } else { \
            fails++; \
            printf("%s:%d: %s%s failed, expected %f, got %f (diff %f > %f)\n", __FILE__, __LINE__, context, #x, (double)(expect), (double)val, (double)diff, (double)(accuracy)); \
        } \
    } while (0)

#define TEST_FLT_SIGN(x, expect) do { \
        tests++; \
        long double val = (x); \
        long double expval = (expect); \
        if (val != expval || !!signbit(val) != !!signbit(expval)) { \
            fails++; \
            printf("%s:%d: %s%s failed, expected %f, got %f\n", __FILE__, __LINE__, context, #x, (double)expval, (double)val); \
        } \
    } while (0)

#define TEST_INT(x, expect) do { \
        tests++; \
        if ((x) != (expect)) { \
            fails++; \
            printf("%s:%d: %s%s failed, expected %lld, got %lld\n", __FILE__, __LINE__, context, #x, (long long)(expect), (long long)(x)); \
        } \
    } while (0)

#define TEST_PTR(x, expect) do { \
        tests++; \
        if ((x) != (expect)) { \
            fails++; \
            printf("%s:%d: %s%s failed, expected %p, got %p\n", __FILE__, __LINE__, context, #x, (expect), (x)); \
        } \
    } while (0)

#define F(x) strtod(#x, NULL)
#define L(x) strtol(#x, NULL, 0)
#define UL(x) strtoul(#x, NULL, 0)
#define LL(x) strtoll(#x, NULL, 0)
#define ULL(x) strtoull(#x, NULL, 0)

int vsscanf_wrap(const char* str, const char* fmt, ...) {
    va_list ap;
    int ret;
    va_start(ap, fmt);
    ret = vsscanf(str, fmt, ap);
    va_end(ap);
    return ret;
}

int main(int argc, char* argv[]) {
    char buf[200];
    int i;
    uint64_t myconst = 0xbaadf00dcafe;

    snprintf(buf, sizeof(buf), "%f", 3.141592654);
    TEST_STR(buf, "3.141593");
    snprintf(buf, sizeof(buf), "%"PRIx64" %"PRIx64" %"PRIx64" %"PRIx64" %"PRIx64" %"PRIx64" %"PRIx64" %"PRIx64" %"PRIx64" %"PRIx64, myconst + 0, myconst + 1, myconst + 2, myconst + 3, myconst + 4, myconst + 5, myconst + 6, myconst + 7, myconst + 8, myconst + 9);
    TEST_STR(buf, "baadf00dcafe baadf00dcaff baadf00dcb00 baadf00dcb01 baadf00dcb02 baadf00dcb03 baadf00dcb04 baadf00dcb05 baadf00dcb06 baadf00dcb07");

    uint64_t val0, val1, val2, val3, val4, val5, val6, val7, val8, val9;
    if (sscanf("baadf00dcafe baadf00dcaff baadf00dcb00 baadf00dcb01 baadf00dcb02 baadf00dcb03 baadf00dcb04 baadf00dcb05 baadf00dcb06 baadf00dcb07", "%"SCNx64" %"SCNx64" %"SCNx64" %"SCNx64" %"SCNx64" %"SCNx64" %"SCNx64" %"SCNx64" %"SCNx64" %"SCNx64, &val0, &val1, &val2, &val3, &val4, &val5, &val6, &val7, &val8, &val9) != 10) {
        fails++;
        printf("sscanf failed\n");
    } else {
        int64_t diff = 0;
        diff += llabs((int64_t)(val0 - 0 - myconst));
        diff += llabs((int64_t)(val1 - 1 - myconst));
        diff += llabs((int64_t)(val2 - 2 - myconst));
        diff += llabs((int64_t)(val3 - 3 - myconst));
        diff += llabs((int64_t)(val4 - 4 - myconst));
        diff += llabs((int64_t)(val5 - 5 - myconst));
        diff += llabs((int64_t)(val6 - 6 - myconst));
        diff += llabs((int64_t)(val7 - 7 - myconst));
        diff += llabs((int64_t)(val8 - 8 - myconst));
        diff += llabs((int64_t)(val9 - 9 - myconst));
        if (diff != 0) {
            fails++;
            printf("sscanf output failed\n");
        }
    }
    tests++;

    val0 = val1 = val2 = val3 = val4 = val5 = val6 = val7 = val8 = val9 = 0xff;
    if (vsscanf_wrap("baadf00dcafe baadf00dcaff baadf00dcb00 baadf00dcb01 baadf00dcb02 baadf00dcb03 baadf00dcb04 baadf00dcb05 baadf00dcb06 baadf00dcb07", "%"SCNx64" %"SCNx64" %"SCNx64" %"SCNx64" %"SCNx64" %"SCNx64" %"SCNx64" %"SCNx64" %"SCNx64" %"SCNx64, &val0, &val1, &val2, &val3, &val4, &val5, &val6, &val7, &val8, &val9) != 10) {
        fails++;
        printf("vsscanf failed\n");
    } else {
        int64_t diff = 0;
        diff += llabs((int64_t)(val0 - 0 - myconst));
        diff += llabs((int64_t)(val1 - 1 - myconst));
        diff += llabs((int64_t)(val2 - 2 - myconst));
        diff += llabs((int64_t)(val3 - 3 - myconst));
        diff += llabs((int64_t)(val4 - 4 - myconst));
        diff += llabs((int64_t)(val5 - 5 - myconst));
        diff += llabs((int64_t)(val6 - 6 - myconst));
        diff += llabs((int64_t)(val7 - 7 - myconst));
        diff += llabs((int64_t)(val8 - 8 - myconst));
        diff += llabs((int64_t)(val9 - 9 - myconst));
        if (diff != 0) {
            fails++;
            printf("vsscanf output failed\n");
        }
    }
    tests++;

    float val_f;
    double val_d;
    if (sscanf("0.8 0.8", "%f %lf", &val_f, &val_d) != 2) {
        fails++;
        printf("sscanf for floats failed\n");
    } else {
        double diff = 0;
        diff += fabs(val_f - 0.8);
        diff += fabs(val_d - 0.8);
        // Testing for the success case, to make NaNs trigger the failure case
        if (diff < 0.0001) {
            // All ok
        } else {
            fails++;
            printf("sscanf output for floats failed, %f %f - diff %f\n", val_f, val_d, diff);
        }
    }
    tests++;
#if !defined(__MINGW32__) || (!defined(__i386__) && !defined(__x86_64__)) || (defined(__USE_MINGW_ANSI_STDIO) && __USE_MINGW_ANSI_STDIO)
    long double val_ld;
    if (sscanf("0.8", "%Lf", &val_ld) != 1) {
        fails++;
        printf("sscanf for long double failed\n");
    } else {
        // Testing for the success case, to make NaNs trigger the failure case
        if (fabsl(val_ld - 0.8) < 0.0001) {
            // All ok
        } else {
            fails++;
            printf("sscanf output for long double failed, %f vs %f\n", (double) val_ld, 0.8);
        }
    }
    tests++;
#endif

#ifdef _WIN32
    _set_invalid_parameter_handler(invalid_parameter);
#endif
    errno = 0;
    TEST_INT(strtol("foo", NULL, 100), 0);
    TEST_INT(errno, EINVAL);

    int env_ok = 0;
    putenv("CRT_TEST_VAR=1");
    for (char **ptr = environ; *ptr; ptr++)
        if (!strcmp(*ptr, "CRT_TEST_VAR=1"))
            env_ok = 1;
    if (!env_ok) {
        fails++;
        printf("Variable set by putenv not found found in environ\n");
    }
    tests++;
    env_ok = 0;
    putenv("CRT_TEST_VAR=2");
    for (char **ptr = environ; *ptr; ptr++)
        if (!strcmp(*ptr, "CRT_TEST_VAR=2"))
            env_ok = 1;
    if (!env_ok) {
        fails++;
        printf("Variable updated by putenv not found found in environ\n");
    }
    tests++;

#define TEST_FLOOR(floor) \
    TEST_FLT(floor(F(3.9)), 3.0); \
    TEST_FLT(floor(F(-3.3)), -4.0); \
    TEST_FLT(floor(F(-3.9)), -4.0); \
    TEST_FLT(floor(F(17179869184.0)), 17179869184.0); \
    TEST_FLT(floor(F(1329227995784915872903807060280344576.0)), 1329227995784915872903807060280344576.0); \
    TEST_FLT(floor(F(INFINITY)), INFINITY); \
    TEST_FLT(floor(F(-INFINITY)), -INFINITY); \
    TEST_FLT_NAN(floor(F(NAN)), F(NAN)); \
    TEST_FLT_NAN(floor(-F(NAN)), -F(NAN))

    TEST_FLOOR(floor);
    TEST_FLOOR(floorf);
    TEST_FLOOR(floorl);

#define TEST_CEIL(ceil) \
    TEST_FLT(ceil(F(3.9)), 4.0); \
    TEST_FLT(ceil(F(-3.3)), -3.0); \
    TEST_FLT(ceil(F(-3.9)), -3.0); \
    TEST_FLT(ceil(F(17179869184.0)), 17179869184.0); \
    TEST_FLT(ceil(F(1329227995784915872903807060280344576.0)), 1329227995784915872903807060280344576.0); \
    TEST_FLT(ceil(F(INFINITY)), INFINITY); \
    TEST_FLT(ceil(F(-INFINITY)), -INFINITY); \
    TEST_FLT_NAN(ceil(F(NAN)), F(NAN)); \
    TEST_FLT_NAN(ceil(-F(NAN)), -F(NAN))

    TEST_CEIL(ceil);
    TEST_CEIL(ceilf);
    TEST_CEIL(ceill);

#define TEST_TRUNC(trunc) \
    TEST_FLT(trunc(F(3.9)), 3.0); \
    TEST_FLT(trunc(F(-3.3)), -3.0); \
    TEST_FLT(trunc(F(-3.9)), -3.0); \
    TEST_FLT(trunc(F(17179869184.0)), 17179869184.0); \
    TEST_FLT(trunc(F(1329227995784915872903807060280344576.0)), 1329227995784915872903807060280344576.0); \
    TEST_FLT(trunc(F(INFINITY)), INFINITY); \
    TEST_FLT(trunc(F(-INFINITY)), -INFINITY); \
    TEST_FLT_NAN(trunc(F(NAN)), F(NAN)); \
    TEST_FLT_NAN(trunc(-F(NAN)), -F(NAN))

    TEST_TRUNC(trunc);
    TEST_TRUNC(truncf);
    TEST_TRUNC(truncl);

#define TEST_SQRT(sqrt) \
    TEST_FLT(sqrt(F(9)), 3.0); \
    TEST_FLT(sqrt(F(0.25)), 0.5); \
    TEST_FLT(sqrt(F(INFINITY)), INFINITY); \
    TEST_FLT_NAN_ANY(sqrt(F(-1.0))); \
    TEST_FLT_NAN_ANY(sqrt(F(-INFINITY))); \
    TEST_FLT_NAN(sqrt(F(NAN)), F(NAN)); \
    TEST_FLT_NAN(sqrt(-F(NAN)), -F(NAN))

    TEST_SQRT(sqrt);
    TEST_SQRT(sqrtf);
    TEST_SQRT(sqrtl);

#define TEST_CBRT(cbrt) \
    TEST_FLT_ACCURACY(cbrt(F(27)), 3.0, 0.001); \
    TEST_FLT_ACCURACY(cbrt(F(-27)), -3.0, 0.001); \
    TEST_FLT_ACCURACY(cbrt(F(0.125)), 0.5, 0.001); \
    TEST_FLT_ACCURACY(cbrt(F(-0.125)), -0.5, 0.001); \
    TEST_FLT(cbrt(F(INFINITY)), INFINITY); \
    TEST_FLT(cbrt(F(-INFINITY)), -INFINITY); \
    TEST_FLT_NAN(cbrt(F(NAN)), F(NAN)); \
    TEST_FLT_NAN(cbrt(-F(NAN)), -F(NAN))

    TEST_CBRT(cbrt);
    TEST_CBRT(cbrtf);
    TEST_CBRT(cbrtl);

#define TEST_HYPOT(hypot) \
    TEST_FLT_ACCURACY(hypot(F(1.0), F(1.0)), 1.414214, 0.001); \
    TEST_FLT_ACCURACY(hypot(F(-1.0), F(1.0)), 1.414214, 0.001); \
    TEST_FLT_ACCURACY(hypot(F(1.0), F(-1.0)), 1.414214, 0.001); \
    TEST_FLT_ACCURACY(hypot(F(-1.0), F(-1.0)), 1.414214, 0.001); \
    TEST_FLT(hypot(F(INFINITY), F(0.0)), INFINITY); \
    TEST_FLT(hypot(F(-INFINITY), F(0.0)), INFINITY); \
    TEST_FLT(hypot(F(0.0), F(INFINITY)), INFINITY); \
    TEST_FLT(hypot(F(0.0), F(-INFINITY)), INFINITY); \
    TEST_FLT_NAN_ANY(hypot(F(NAN), F(0.0))); \
    TEST_FLT_NAN_ANY(hypot(F(0.0), F(NAN)))

    TEST_HYPOT(hypot);
    TEST_HYPOT(hypotf);
    TEST_HYPOT(hypotl);

#define TEST_FMA(fma) \
    TEST_FLT(fma(F(2), F(3), F(4)), 10); \
    TEST_FLT_NAN(fma(F(NAN), F(3), F(4)), F(NAN)); \
    TEST_FLT_NAN(fma(F(2), F(NAN), F(4)), F(NAN)); \
    TEST_FLT_NAN(fma(F(2), F(3), F(NAN)), F(NAN))

    TEST_FMA(fma);
    TEST_FMA(fmaf);
    TEST_FMA(fmal);

    double retd;
    float retf;
    long double retl;
#define TEST_MODF(modf, retd) \
    TEST_FLT_ACCURACY(modf(F(2.1), &retd), 0.1, 0.001); \
    TEST_FLT(retd, 2); \
    TEST_FLT_ACCURACY(modf(F(-2.1), &retd), -0.1, 0.001); \
    TEST_FLT(retd, -2); \
    TEST_FLT(modf(F(17179869184.0), &retd), 0); \
    TEST_FLT(retd, 17179869184.0); \
    TEST_FLT(modf(F(1329227995784915872903807060280344576.0), &retd), 0); \
    TEST_FLT(retd, 1329227995784915872903807060280344576.0); \
    TEST_FLT(modf(F(INFINITY), &retd), 0); \
    TEST_FLT(retd, INFINITY); \
    TEST_FLT(modf(F(-INFINITY), &retd), 0); \
    TEST_FLT(retd, -INFINITY); \
    TEST_FLT_NAN(modf(F(NAN), &retd), F(NAN)); \
    TEST_FLT_NAN(retd, F(NAN)); \
    TEST_FLT_NAN(modf(-F(NAN), &retd), -F(NAN)); \
    TEST_FLT_NAN(retd, -F(NAN))

    TEST_MODF(modf, retd);
    TEST_MODF(modff, retf);
    TEST_MODF(modfl, retl);

#define TEST_FMOD(fmod) \
    TEST_FLT_ACCURACY(fmod(F(3.9), F(4.0)), 3.9, 0.001); \
    TEST_FLT_ACCURACY(fmod(F(7.9), F(4.0)), 3.9, 0.001); \
    TEST_FLT_ACCURACY(fmod(F(-3.9), F(4.0)), -3.9, 0.001); \
    TEST_FLT_ACCURACY(fmod(F(3.9), F(-4.0)), 3.9, 0.001); \
    TEST_FLT_ACCURACY(fmod(F(7.9), F(-4.0)), 3.9, 0.001); \
    TEST_FLT_ACCURACY(fmod(F(-3.9), F(-4.0)), -3.9, 0.001); \
    TEST_FLT(fmod(F(17179869184.0), F(17180917760.0)), 17179869184.0); \
    TEST_FLT(fmod(F(17179869184.0), F(1.0)), 0.0); \
    TEST_FLT(fmod(F(1329227995784915872903807060280344576.0), F(1330526069999549579810939684362649600.0)), 1329227995784915872903807060280344576.0); \
    TEST_FLT(fmod(F(1329227995784915872903807060280344576.0), F(1.0)), 0.0); \
    TEST_FLT_NAN_ANY(fmod(F(INFINITY), F(4.0))); \
    TEST_FLT_NAN_ANY(fmod(F(-INFINITY), F(4.0))); \
    TEST_FLT_NAN(fmod(F(0), F(NAN)), F(NAN)); \
    TEST_FLT_NAN(fmod(F(0), -F(NAN)), -F(NAN)); \
    TEST_FLT_NAN(fmod(F(NAN), F(1)), F(NAN)); \
    TEST_FLT_NAN(fmod(-F(NAN), F(1)), -F(NAN)); \
    TEST_FLT_NAN_ANY(fmod(F(3.9), F(0))); \
    TEST_FLT_ACCURACY(fmod(F(3.9), F(INFINITY)), 3.9, 0.001); \
    TEST_FLT_ACCURACY(fmod(F(3.9), F(-INFINITY)), 3.9, 0.001)

    TEST_FMOD(fmod);
    TEST_FMOD(fmodf);
    TEST_FMOD(fmodl);

#define TEST_REMAINDER(remainder) \
    TEST_FLT_ACCURACY(remainder(F(1.9), F(4.0)), 1.9, 0.001); \
    TEST_FLT(remainder(F(2.0), F(4.0)), 2.0); \
    TEST_FLT(remainder(F(6.0), F(4.0)), -2.0); \
    TEST_FLT(remainder(F(-6.0), F(4.0)), 2.0); \
    TEST_FLT_ACCURACY(remainder(F(3.9), F(4.0)), -0.1, 0.001); \
    TEST_FLT_ACCURACY(remainder(F(-2.0), F(4.0)), -2.0, 0.001); \
    TEST_FLT_ACCURACY(remainder(F(-3.9), F(4.0)), 0.1, 0.001); \
    TEST_FLT_ACCURACY(remainder(F(-4.1), F(4.0)), -0.1, 0.001); \
    TEST_FLT_ACCURACY(remainder(F(3.9), F(-4.0)), -0.1, 0.001); \
    TEST_FLT_ACCURACY(remainder(F(-3.9), F(-4.0)), 0.1, 0.001); \
    TEST_FLT(remainder(F(17179869184.0), F(17180917760.0)), -1048576.0); \
    TEST_FLT(remainder(F(17179869184.0), F(1.0)), 0.0); \
    TEST_FLT(remainder(F(1329227995784915872903807060280344576.0), F(1330526069999549579810939684362649600.0)), -1298074214633706907132624082305024.0); \
    TEST_FLT(remainder(F(1329227995784915872903807060280344576.0), F(1.0)), 0.0); \
    TEST_FLT_NAN_ANY(remainder(F(INFINITY), F(4.0))); \
    TEST_FLT_NAN_ANY(remainder(F(-INFINITY), F(4.0))); \
    TEST_FLT_NAN(remainder(F(0), F(NAN)), F(NAN)); \
    TEST_FLT_NAN(remainder(F(0), -F(NAN)), -F(NAN)); \
    TEST_FLT_NAN(remainder(F(NAN), F(1)), F(NAN)); \
    TEST_FLT_NAN(remainder(-F(NAN), F(1)), -F(NAN)); \
    TEST_FLT_NAN_ANY(remainder(F(1.9), F(0)))

    TEST_REMAINDER(remainder);
    TEST_REMAINDER(remainderf);
    TEST_REMAINDER(remainderl);

    int quo = 42;
#define TEST_REMQUO(remquo) \
    TEST_FLT_ACCURACY(remquo(F(1.9), F(4.0), &quo), 1.9, 0.001); \
    TEST_INT(quo, 0); \
    TEST_FLT(remquo(F(2.0), F(4.0), &quo), 2.0); \
    TEST_INT(quo, 0); \
    TEST_FLT(remquo(F(6.0), F(4.0), &quo), -2.0); \
    TEST_INT(quo, 2); \
    TEST_FLT(remquo(F(-6.0), F(4.0), &quo), 2.0); \
    TEST_INT(quo, -2); \
    TEST_FLT(remquo(F(17179869184.0), F(17180917760.0), &quo), -1048576.0); \
    TEST_INT(quo, 1); \
    TEST_FLT(remquo(F(1329227995784915872903807060280344576.0), F(1330526069999549579810939684362649600.0), &quo), -1298074214633706907132624082305024.0); \
    TEST_INT(quo, 1); \
    TEST_FLT_ACCURACY(remquo(F(3.9), F(4.0), &quo), -0.1, 0.001); \
    TEST_INT(quo, 1); \
    TEST_FLT_ACCURACY(remquo(F(-2.0), F(4.0), &quo), -2.0, 0.001); \
    TEST_INT(quo, 0); \
    TEST_FLT_ACCURACY(remquo(F(-3.9), F(4.0), &quo), 0.1, 0.001); \
    TEST_INT(quo, -1); \
    TEST_FLT_ACCURACY(remquo(F(-4.1), F(4.0), &quo), -0.1, 0.001); \
    TEST_INT(quo, -1); \
    TEST_FLT_ACCURACY(remquo(F(3.9), F(-4.0), &quo), -0.1, 0.001); \
    TEST_INT(quo, -1); \
    TEST_FLT_ACCURACY(remquo(F(-3.9), F(-4.0), &quo), 0.1, 0.001); \
    TEST_INT(quo, 1); \
    TEST_FLT_NAN_ANY(remquo(F(INFINITY), F(4.0), &quo)); \
    TEST_FLT_NAN_ANY(remquo(F(-INFINITY), F(4.0), &quo)); \
    TEST_FLT_NAN(remquo(F(0), F(NAN), &quo), F(NAN)); \
    TEST_FLT_NAN(remquo(F(0), -F(NAN), &quo), -F(NAN)); \
    TEST_FLT_NAN(remquo(F(NAN), F(0), &quo), F(NAN)); \
    TEST_FLT_NAN(remquo(-F(NAN), F(0), &quo), -F(NAN)); \
    TEST_FLT_NAN_ANY(remquo(F(1.9), F(0), &quo));

    TEST_REMQUO(remquo);
    TEST_REMQUO(remquof);
    TEST_REMQUO(remquol);

    for (i = 0; i < 2; i++) {
        if (i == 0) {
            // Use the default env in the first round here
            context = "FE_DFL_ENV ";
        } else {
            fesetround(FE_TONEAREST); // Only set it on the second round
            context = "FE_TONEAREST ";
        }

#define TEST_LRINT_NEAREST(lrint) \
        TEST_INT(lrint(F(3.3)), 3); \
        TEST_INT(lrint(F(3.6)), 4); \
        TEST_INT(lrint(F(3.5)), 4); \
        TEST_INT(lrint(F(4.5)), 4); \
        TEST_INT(lrint(F(1073741824.0)), 1073741824); \
        TEST_INT(lrint(F(-3.3)), -3); \
        TEST_INT(lrint(F(-3.6)), -4); \
        TEST_INT(lrint(F(-3.5)), -4); \
        TEST_INT(lrint(F(-4.5)), -4)

#define TEST_LLRINT_NEAREST(llrint) \
        TEST_INT(llrint(F(17179869184.0)), 17179869184); \
        TEST_INT(llrint(F(1152921504606846976.0)), 1152921504606846976)

        TEST_LRINT_NEAREST(llrint);
        TEST_LRINT_NEAREST(llrintf);
        TEST_LRINT_NEAREST(llrintl);
        TEST_LRINT_NEAREST(lrint);
        TEST_LRINT_NEAREST(lrintf);
        TEST_LRINT_NEAREST(lrintl);
        TEST_LLRINT_NEAREST(llrint);
        TEST_LLRINT_NEAREST(llrintf);
        TEST_LLRINT_NEAREST(llrintl);

#define TEST_RINT_NEAREST(rint) \
        TEST_FLT(rint(F(3.3)), 3.0); \
        TEST_FLT(rint(F(3.6)), 4.0); \
        TEST_FLT(rint(F(3.5)), 4.0); \
        TEST_FLT(rint(F(4.5)), 4.0); \
        TEST_FLT(rint(F(17179869184.0)), 17179869184.0); \
        TEST_FLT(rint(F(1329227995784915872903807060280344576.0)), 1329227995784915872903807060280344576.0); \
        TEST_FLT_NAN(rint(F(NAN)), F(NAN)); \
        TEST_FLT(rint(F(-3.3)), -3.0); \
        TEST_FLT(rint(F(-3.6)), -4.0); \
        TEST_FLT(rint(F(-3.5)), -4.0); \
        TEST_FLT(rint(F(-4.5)), -4.0); \
        TEST_FLT_NAN(rint(-F(NAN)), -F(NAN))

        TEST_RINT_NEAREST(rint);
        TEST_RINT_NEAREST(rintf);
        TEST_RINT_NEAREST(rintl);
        TEST_RINT_NEAREST(nearbyint);
        TEST_RINT_NEAREST(nearbyintf);
        TEST_RINT_NEAREST(nearbyintl);
    }

    fesetround(FE_TOWARDZERO);
    context = "FE_TOWARDZERO ";

#define TEST_LRINT_TOWARDZERO(lrint) \
    TEST_INT(lrint(F(3.3)), 3); \
    TEST_INT(lrint(F(3.6)), 3); \
    TEST_INT(lrint(F(-3.3)), -3); \
    TEST_INT(lrint(F(-3.6)), -3)

    TEST_LRINT_TOWARDZERO(llrint);
    TEST_LRINT_TOWARDZERO(llrintf);
    TEST_LRINT_TOWARDZERO(llrintl);
    TEST_LRINT_TOWARDZERO(lrint);
    TEST_LRINT_TOWARDZERO(lrintf);
    TEST_LRINT_TOWARDZERO(lrintl);

#define TEST_RINT_TOWARDZERO(rint) \
    TEST_FLT(rint(F(3.3)), 3.0); \
    TEST_FLT(rint(F(3.6)), 3.0); \
    TEST_FLT(rint(F(-3.3)), -3.0); \
    TEST_FLT(rint(F(-3.6)), -3.0)

    TEST_RINT_TOWARDZERO(rint);
    TEST_RINT_TOWARDZERO(rintf);
    TEST_RINT_TOWARDZERO(rintl);
    TEST_RINT_TOWARDZERO(nearbyint);
    TEST_RINT_TOWARDZERO(nearbyintf);
    TEST_RINT_TOWARDZERO(nearbyintl);

    fesetround(FE_DOWNWARD);
    context = "FE_DOWNWARD ";

#define TEST_LRINT_DOWNWARD(lrint) \
    TEST_INT(lrint(F(3.3)), 3); \
    TEST_INT(lrint(F(3.6)), 3); \
    TEST_INT(lrint(F(-3.3)), -4); \
    TEST_INT(lrint(F(-3.6)), -4)

    TEST_LRINT_DOWNWARD(llrint);
    TEST_LRINT_DOWNWARD(llrintf);
    TEST_LRINT_DOWNWARD(llrintl);
    TEST_LRINT_DOWNWARD(lrint);
    TEST_LRINT_DOWNWARD(lrintf);
    TEST_LRINT_DOWNWARD(lrintl);

#define TEST_RINT_DOWNWARD(rint) \
    TEST_FLT(rint(F(3.3)), 3.0); \
    TEST_FLT(rint(F(3.6)), 3.0); \
    TEST_FLT(rint(F(-3.3)), -4.0); \
    TEST_FLT(rint(F(-3.6)), -4.0)

    TEST_RINT_DOWNWARD(rint);
    TEST_RINT_DOWNWARD(rintf);
    TEST_RINT_DOWNWARD(rintl);
    TEST_RINT_DOWNWARD(nearbyint);
    TEST_RINT_DOWNWARD(nearbyintf);
    TEST_RINT_DOWNWARD(nearbyintl);

    fesetround(FE_UPWARD);
    context = "FE_UPWARD ";

#define TEST_LRINT_UPWARD(lrint) \
    TEST_INT(lrint(F(3.3)), 4); \
    TEST_INT(lrint(F(3.6)), 4); \
    TEST_INT(lrint(F(-3.3)), -3); \
    TEST_INT(lrint(F(-3.6)), -3)

    TEST_LRINT_UPWARD(llrint);
    TEST_LRINT_UPWARD(llrintf);
    TEST_LRINT_UPWARD(llrintl);
    TEST_LRINT_UPWARD(lrint);
    TEST_LRINT_UPWARD(lrintf);
    TEST_LRINT_UPWARD(lrintl);

#define TEST_RINT_UPWARD(rint) \
    TEST_FLT(rint(F(3.3)), 4.0); \
    TEST_FLT(rint(F(3.6)), 4.0); \
    TEST_FLT(rint(F(-3.3)), -3.0); \
    TEST_FLT(rint(F(-3.6)), -3.0)

    TEST_RINT_UPWARD(rint);
    TEST_RINT_UPWARD(rintf);
    TEST_RINT_UPWARD(rintl);
    TEST_RINT_UPWARD(nearbyint);
    TEST_RINT_UPWARD(nearbyintf);
    TEST_RINT_UPWARD(nearbyintl);

    context = "";
    fesetround(FE_TONEAREST);

#define TEST_LOG(log, HUGE_VAL) \
    TEST_FLT_ACCURACY(log(F(1.0)), 0.0, 0.001); \
    TEST_FLT_ACCURACY(log(F(2.7182818)), 1.0, 0.001); \
    TEST_FLT_ACCURACY(log(F(7.3890561)), 2.0, 0.001); \
    TEST_FLT_ACCURACY(log(F(0.3678794)), -1.0, 0.001); \
    TEST_FLT(log(F(INFINITY)), INFINITY); \
    TEST_FLT_NAN(log(F(NAN)), F(NAN)); \
    TEST_FLT_NAN(log(-F(NAN)), -F(NAN)); \
    TEST_FLT(log(F(0)), -HUGE_VAL); \
    TEST_FLT_NAN_ANY(log(F(-1.0))); \
    TEST_FLT_NAN_ANY(log(F(-INFINITY)))

    TEST_LOG(log, HUGE_VAL);
    TEST_LOG(logf, HUGE_VALF);
    TEST_LOG(logl, HUGE_VALL);

#define TEST_LOG2(log2, HUGE_VAL) \
    TEST_FLT_ACCURACY(log2(F(1.0)), 0.0, 0.001); \
    TEST_FLT_ACCURACY(log2(F(8.0)), 3.0, 0.001); \
    TEST_FLT_ACCURACY(log2(F(1024.0)), 10.0, 0.001); \
    TEST_FLT_ACCURACY(log2(F(1048576.0)), 20.0, 0.001); \
    TEST_FLT_ACCURACY(log2(F(4294967296.0)), 32.0, 0.001); \
    TEST_FLT_ACCURACY(log2(F(0.5)), -1.0, 0.001); \
    TEST_FLT_ACCURACY(log2(F(0.125)), -3.0, 0.001); \
    TEST_FLT_ACCURACY(log2(F(9.7656e-04)), -10, 0.001); \
    TEST_FLT_ACCURACY(log2(F(9.5367e-07)), -20, 0.001); \
    TEST_FLT_ACCURACY(log2(F(3.5527e-15)), -48, 0.001); \
    TEST_FLT_ACCURACY(log2(F(7.8886e-31)), -100, 0.001); \
    TEST_FLT_ACCURACY(log2(F(7.3468e-40)), -130, 0.001); \
    TEST_FLT_ACCURACY(log2(F(1.225000)), 0.292782, 0.001); /* This, with log2f, crashes the mingw-w64 softfloat implementation */ \
    TEST_FLT(log2(F(INFINITY)), INFINITY); \
    TEST_FLT_NAN(log2(F(NAN)), F(NAN)); \
    TEST_FLT_NAN(log2(-F(NAN)), -F(NAN)); \
    TEST_FLT(log2(F(0)), -HUGE_VAL); \
    TEST_FLT_NAN_ANY(log2(F(-1.0))); \
    TEST_FLT_NAN_ANY(log2(F(-INFINITY)))

    TEST_LOG2(log2, HUGE_VAL);
    TEST_LOG2(log2f, HUGE_VALF);
    TEST_LOG2(log2l, HUGE_VALL);

#if !defined(__MINGW32__) || !defined(__arm__)
    // In Wine on arm, the strtod() in the F() macro returns 0 instead of
    // the actual denormal value.
    TEST_FLT_ACCURACY(log2(F(9.8813e-324)), -1073, 0.001);
#endif
    TEST_FLT_ACCURACY(log2f(F(7.1746e-43)), -140, 0.001);
    TEST_FLT_ACCURACY(log2l(F(7.1746e-43)), -140, 0.001);

#define TEST_LOG10(log10, HUGE_VAL) \
    TEST_FLT_ACCURACY(log10(F(1.0)), 0.0, 0.001); \
    TEST_FLT_ACCURACY(log10(F(10.0)), 1.0, 0.001); \
    TEST_FLT_ACCURACY(log10(F(100.0)), 2.0, 0.001); \
    TEST_FLT_ACCURACY(log10(F(0.1)), -1.0, 0.001); \
    TEST_FLT(log10(F(INFINITY)), INFINITY); \
    TEST_FLT_NAN(log10(F(NAN)), F(NAN)); \
    TEST_FLT_NAN(log10(-F(NAN)), -F(NAN)); \
    TEST_FLT(log10(F(0)), -HUGE_VAL); \
    TEST_FLT_NAN_ANY(log10(F(-1.0))); \
    TEST_FLT_NAN_ANY(log10(F(-INFINITY)))

    TEST_LOG10(log10, HUGE_VAL);
    TEST_LOG10(log10f, HUGE_VALF);
    TEST_LOG10(log10l, HUGE_VALL);

#define TEST_LOG1P(log1p, HUGE_VAL) \
    TEST_FLT_ACCURACY(log1p(F(0.0)), 0.0, 0.001); \
    TEST_FLT_ACCURACY(log1p(F(1.718282)), 1.0, 0.001); \
    TEST_FLT_ACCURACY(log1p(F(-0.632120)), -1.0, 0.001); \
    TEST_FLT(log1p(F(INFINITY)), INFINITY); \
    TEST_FLT_NAN(log1p(F(NAN)), F(NAN)); \
    TEST_FLT_NAN(log1p(-F(NAN)), -F(NAN)); \
    TEST_FLT(log1p(F(-1.0)), -HUGE_VAL); \
    TEST_FLT_NAN_ANY(log1p(F(-2.0))); \
    TEST_FLT_NAN_ANY(log1p(F(-INFINITY)))

    TEST_LOG1P(log1p, HUGE_VAL);
    TEST_LOG1P(log1pf, HUGE_VALF);
    TEST_LOG1P(log1pl, HUGE_VALL);

#define TEST_EXP(exp) \
    TEST_FLT_ACCURACY(exp(F(0.0)), 1.0, 0.001); \
    TEST_FLT_ACCURACY(exp(F(1.0)), 2.7182818, 0.001); \
    TEST_FLT_ACCURACY(exp(F(2.0)), 7.3890561, 0.001); \
    TEST_FLT_ACCURACY(exp(F(-1.0)), 0.3678794, 0.001); \
    TEST_FLT(exp(F(INFINITY)), INFINITY); \
    TEST_FLT(exp(F(-INFINITY)), 0); \
    TEST_FLT_NAN(exp(F(NAN)), F(NAN)); \
    TEST_FLT_NAN(exp(-F(NAN)), -F(NAN))

    TEST_EXP(exp);
    TEST_EXP(expf);
    TEST_EXP(expl);

#define TEST_EXP2(exp2) \
    TEST_FLT_ACCURACY(exp2(F(0.0)), 1.0, 0.001); \
    TEST_FLT_ACCURACY(exp2(F(3.0)), 8.0, 0.001); \
    TEST_FLT_ACCURACY(exp2(F(10.0)), 1024.0, 0.001); \
    TEST_FLT_ACCURACY(exp2(F(20.0)), 1048576.0, 0.001); \
    TEST_FLT_ACCURACY(exp2(F(32.0)), 4294967296.0, 0.001); \
    TEST_FLT_ACCURACY(exp2(F(-2.0)), 0.25, 0.001); \
    TEST_FLT(exp2(F(INFINITY)), INFINITY); \
    TEST_FLT(exp2(F(-INFINITY)), 0); \
    TEST_FLT_NAN(exp2(F(NAN)), F(NAN)); \
    TEST_FLT_NAN(exp2(-F(NAN)), -F(NAN))

    TEST_EXP2(exp2);
    TEST_EXP2(exp2f);
    TEST_EXP2(exp2l);

#define TEST_EXPM1(expm1) \
    TEST_FLT_ACCURACY(expm1(F(0.0)), 0.0, 0.001); \
    TEST_FLT_ACCURACY(expm1(F(1.0)), 1.718282, 0.001); \
    TEST_FLT_ACCURACY(expm1(F(-1.0)), -0.632120, 0.001); \
    TEST_FLT(expm1(F(INFINITY)), INFINITY); \
    TEST_FLT(expm1(F(-INFINITY)), -1.0); \
    TEST_FLT_NAN(expm1(F(NAN)), F(NAN)); \
    TEST_FLT_NAN(expm1(-F(NAN)), -F(NAN))

    TEST_EXPM1(expm1);
    TEST_EXPM1(expm1f);
    TEST_EXPM1(expm1l);

#define TEST_LDEXP(ldexp) \
    TEST_FLT_ACCURACY(ldexp(F(0.0), 1), 0.0, 0.001); \
    TEST_FLT_ACCURACY(ldexp(F(2.0), 2), 8.0, 0.001); \
    TEST_FLT_ACCURACY(ldexp(F(2.0), -2), 0.5, 0.001); \
    TEST_FLT(ldexp(F(INFINITY), -42), INFINITY); \
    TEST_FLT(ldexp(F(-INFINITY), 42), -INFINITY); \
    TEST_FLT_NAN(ldexp(F(NAN), 42), F(NAN)); \
    TEST_FLT_NAN(ldexp(-F(NAN), 42), -F(NAN))

    TEST_LDEXP(ldexp);
    TEST_LDEXP(ldexpf);
    TEST_LDEXP(ldexpl);

#define TEST_SCALBN(scalbn) \
    TEST_FLT_ACCURACY(scalbn(F(0.0), 1), 0.0, 0.001); \
    TEST_FLT_ACCURACY(scalbn(F(2.0), 2), 8.0, 0.001); \
    TEST_FLT_ACCURACY(scalbn(F(2.0), -2), 0.5, 0.001); \
    TEST_FLT(scalbn(F(INFINITY), -42), INFINITY); \
    TEST_FLT(scalbn(F(-INFINITY), 42), -INFINITY); \
    TEST_FLT_NAN(scalbn(F(NAN), 42), F(NAN)); \
    TEST_FLT_NAN(scalbn(-F(NAN), 42), -F(NAN))

    TEST_SCALBN(scalbn);
    TEST_SCALBN(scalbnf);
    TEST_SCALBN(scalbnf);
    TEST_SCALBN(scalbln);
    TEST_SCALBN(scalblnf);
    TEST_SCALBN(scalblnf);

    int iret;
#define TEST_FREXP(frexp) \
    TEST_FLT(frexp(F(INFINITY), &iret), INFINITY); \
    TEST_FLT(frexp(F(-INFINITY), &iret), -INFINITY); \
    TEST_FLT_NAN(frexp(F(NAN), &iret), F(NAN)); \
    TEST_FLT_NAN(frexp(-F(NAN), &iret), -F(NAN)); \
    TEST_FLT(frexp(F(0x1.4p+42), &iret), 0.625); \
    TEST_INT(iret, 43)

    TEST_FREXP(frexp);
    TEST_FREXP(frexpf);
    TEST_FREXP(frexpl);

#define TEST_ILOGB(ilogb) \
    TEST_INT(ilogb(F(1.0)), 0); \
    TEST_INT(ilogb(F(0.25)), -2); \
    TEST_INT(ilogb(F(-0.25)), -2); \
    TEST_INT(ilogb(F(0.0)), FP_ILOGB0); \
    TEST_INT(ilogb(F(INFINITY)), INT_MAX); \
    TEST_INT(ilogb(F(-INFINITY)), INT_MAX); \
    TEST_INT(ilogb(F(NAN)), FP_ILOGBNAN); \
    TEST_INT(ilogb(-F(NAN)), FP_ILOGBNAN)

    TEST_ILOGB(ilogb);
    TEST_ILOGB(ilogbf);
    TEST_ILOGB(ilogbl);

    TEST_INT(ilogb(3.49514e-308), -1022);
    TEST_INT(ilogb(1.74757e-308), -1023);
    TEST_INT(ilogb(9.8813e-324), -1073);

    TEST_INT(ilogbf(F(3.69292e-38)), -125);
    TEST_INT(ilogbf(F(4.61616e-39)), -128);
    TEST_INT(ilogbf(F(1.4013e-45)), -149);

    TEST_INT(ilogbl(3.49514e-308), -1022);
    TEST_INT(ilogbl(1.74757e-308), -1023);
    TEST_INT(ilogbl(9.8813e-324), -1073);

#define TEST_LOGB(logb) \
    TEST_FLT(logb(F(1.0)), 0.0); \
    TEST_FLT(logb(F(0.25)), -2.0); \
    TEST_FLT(logb(F(-0.25)), -2.0); \
    TEST_FLT(logb(F(0.0)), -INFINITY); \
    TEST_FLT(logb(F(INFINITY)), INFINITY); \
    TEST_FLT(logb(F(-INFINITY)), INFINITY); \
    TEST_FLT_NAN(logb(F(NAN)), F(NAN)); \
    TEST_FLT_NAN(logb(-F(NAN)), -F(NAN))

    TEST_LOGB(logb);
    TEST_LOGB(logbf);
    TEST_LOGB(logbl);

    TEST_FLT(logb(3.49514e-308), -1022.0);
    TEST_FLT(logb(1.74757e-308), -1023.0);
    TEST_FLT(logb(9.8813e-324), -1073.0);
    TEST_FLT(logbf(F(3.69292e-38)), -125.0);
    TEST_FLT(logbf(F(4.61616e-39)), -128.0);
    TEST_FLT(logbf(F(1.4013e-45)), -149.0);
    TEST_FLT(logbl(3.49514e-308), -1022.0);
    TEST_FLT(logbl(1.74757e-308), -1023.0);
    TEST_FLT(logbl(9.8813e-324), -1073.0);

#define TEST_LROUND(lround) \
    TEST_INT(lround(F(3.3)), 3); \
    TEST_INT(lround(F(3.6)), 4); \
    TEST_INT(lround(F(3.5)), 4); \
    TEST_INT(lround(F(4.5)), 5); \
    TEST_INT(lround(F(1073741824.0)), 1073741824); \
    TEST_INT(lround(F(-3.3)), -3); \
    TEST_INT(lround(F(-3.6)), -4); \
    TEST_INT(lround(F(-3.5)), -4); \
    TEST_INT(lround(F(-4.5)), -5)

#define TEST_LLROUND(llrint) \
        TEST_INT(llround(F(17179869184.0)), 17179869184); \
        TEST_INT(llround(F(1152921504606846976.0)), 1152921504606846976)

    TEST_LROUND(llround);
    TEST_LROUND(llroundf);
    TEST_LROUND(llroundl);
    TEST_LROUND(lround);
    TEST_LROUND(lroundf);
    TEST_LROUND(lroundl);
    TEST_LLROUND(llround);
    TEST_LLROUND(llroundf);
    TEST_LLROUND(llroundl);

#define TEST_ROUND(round) \
    TEST_FLT(round(F(3.3)), 3.0); \
    TEST_FLT(round(F(3.6)), 4.0); \
    TEST_FLT(round(F(3.5)), 4.0); \
    TEST_FLT(round(F(4.5)), 5.0); \
    TEST_FLT(round(F(17179869184.0)), 17179869184.0); \
    TEST_FLT(round(F(1329227995784915872903807060280344576.0)), 1329227995784915872903807060280344576.0); \
    TEST_FLT(round(F(INFINITY)), INFINITY); \
    TEST_FLT_NAN(round(F(NAN)), F(NAN)); \
    TEST_FLT(round(F(-3.3)), -3.0); \
    TEST_FLT(round(F(-3.6)), -4.0); \
    TEST_FLT(round(F(-3.5)), -4.0); \
    TEST_FLT(round(F(-4.5)), -5.0); \
    TEST_FLT(round(F(-INFINITY)), -INFINITY); \
    TEST_FLT_NAN(round(-F(NAN)), -F(NAN))

    TEST_ROUND(round);
    TEST_ROUND(roundf);
    TEST_ROUND(roundl);

#define TEST_POW(pow) \
    TEST_FLT(pow(F(2.0), F(0.0)), 1.0); \
    TEST_FLT(pow(F(2.0), F(0.0)), 1.0); \
    TEST_FLT(pow(F(10.0), F(0.0)), 1.0); \
    TEST_FLT(pow(F(10.0), F(1.0)), 10.0); \
    TEST_FLT_ACCURACY(pow(F(10.0), F(0.5)), 3.162278, 0.01); \
    TEST_FLT_NAN_ANY(pow(F(-1.0), F(1.5))); \
    TEST_FLT_SIGN(pow(F(0.0), F(3.0)), 0.0); \
    TEST_FLT_SIGN(pow(F(-0.0), F(3.0)), -0.0); \
    TEST_FLT_SIGN(pow(F(0.0), F(4.2)), 0.0); \
    TEST_FLT_SIGN(pow(F(-0.0), F(4.2)), 0.0); \
    TEST_FLT_SIGN(pow(F(INFINITY), F(-0.5)), 0.0); \
    TEST_FLT(pow(F(INFINITY), F(0.5)), INFINITY); \
    TEST_FLT_SIGN(pow(F(-INFINITY), F(-3)), -0.0); \
    TEST_FLT_SIGN(pow(F(-INFINITY), F(-0.5)), 0.0); \
    TEST_FLT(pow(F(-INFINITY), F(3.0)), -INFINITY); \
    TEST_FLT(pow(F(-INFINITY), F(2.5)), INFINITY); \
    TEST_FLT(pow(F(2.0), F(INFINITY)), INFINITY); \
    TEST_FLT(pow(F(1.0), F(INFINITY)), 1.0); \
    TEST_FLT_SIGN(pow(F(0.5), F(INFINITY)), 0.0); \
    TEST_FLT_SIGN(pow(F(2.0), F(-INFINITY)), 0.0); \
    TEST_FLT(pow(F(1.0), F(-INFINITY)), 1.0); \
    TEST_FLT(pow(F(0.5), F(-INFINITY)), INFINITY); \
    TEST_FLT(pow(F(-2.0), F(INFINITY)), INFINITY); \
    TEST_FLT(pow(F(-1.0), F(INFINITY)), 1.0); \
    TEST_FLT_SIGN(pow(F(-0.5), F(INFINITY)), 0.0); \
    TEST_FLT_SIGN(pow(F(-2.0), F(-INFINITY)), 0.0); \
    TEST_FLT(pow(F(-1.0), F(-INFINITY)), 1.0); \
    TEST_FLT(pow(F(-0.5), F(-INFINITY)), INFINITY); \
    TEST_FLT_NAN(pow(F(NAN), F(2.0)), F(NAN)); \
    TEST_FLT_NAN(pow(-F(NAN), F(2.0)), -F(NAN)); \
    TEST_FLT_NAN(pow(F(2.0), F(NAN)), F(NAN)); \
    TEST_FLT_NAN(pow(F(2.0), -F(NAN)), -F(NAN)); \
    TEST_FLT(pow(F(1.0), F(NAN)), 1.0); \
    TEST_FLT(pow(F(1.0), F(INFINITY)), 1.0); \
    TEST_FLT(pow(F(1.0), F(-INFINITY)), 1.0); \
    TEST_FLT(pow(F(NAN), F(0.0)), 1.0); \
    TEST_FLT(pow(F(INFINITY), F(0.0)), 1.0); \
    TEST_FLT(pow(F(-INFINITY), F(0.0)), 1.0)

    TEST_POW(pow);
    TEST_POW(powf);
    TEST_POW(powl);

#define TEST_COS(cos) \
    TEST_FLT_ACCURACY(cos(F(0.0)), 1.0, 0.01); \
    TEST_FLT_ACCURACY(cos(F(3.141592654)/2), 0.0, 0.01); \
    TEST_FLT_ACCURACY(cos(F(3.141592654)), -1.0, 0.01); \
    TEST_FLT_ACCURACY(cos(3*F(3.141592654)/2), 0.0, 0.01); \
    TEST_FLT_ACCURACY(cos(2*F(3.141592654)), 1.0, 0.01); \
    TEST_FLT_NAN_ANY(cos(F(INFINITY))); \
    TEST_FLT_NAN_ANY(cos(F(-INFINITY))); \
    TEST_FLT_NAN(cos(F(NAN)), F(NAN)); \
    TEST_FLT_NAN(cos(-F(NAN)), -F(NAN))

    TEST_COS(cos);
    TEST_COS(cosf);
    TEST_COS(cosl);

#define TEST_SIN(sin) \
    TEST_FLT_ACCURACY(sin(F(0.0)), 0.0, 0.01); \
    TEST_FLT_ACCURACY(sin(F(3.141592654)/2), 1.0, 0.01); \
    TEST_FLT_ACCURACY(sin(F(3.141592654)), 0.0, 0.01); \
    TEST_FLT_ACCURACY(sin(3*F(3.141592654)/2), -1.0, 0.01); \
    TEST_FLT_ACCURACY(sin(2*F(3.141592654)), 0.0, 0.01); \
    TEST_FLT_NAN_ANY(sin(F(INFINITY))); \
    TEST_FLT_NAN_ANY(sin(F(-INFINITY))); \
    TEST_FLT_NAN(sin(F(NAN)), F(NAN)); \
    TEST_FLT_NAN(sin(-F(NAN)), -F(NAN))

    TEST_SIN(sin);
    TEST_SIN(sinf);
    TEST_SIN(sinl);

#define TEST_TAN(tan) \
    TEST_FLT_ACCURACY(tan(F(0.0)), 0.0, 0.01); \
    TEST_FLT_ACCURACY(tan(F(1.0)), 1.557408, 0.01); \
    TEST_FLT_ACCURACY(tan(F(3.141592654)/4), 1.0, 0.01); \
    TEST_FLT_ACCURACY(tan(3*F(3.141592654)/4), -1.0, 0.01); \
    TEST_FLT_ACCURACY(tan(5*F(3.141592654)/4), 1.0, 0.01); \
    TEST_FLT_ACCURACY(tan(7*F(3.141592654)/4), -1.0, 0.01); \
    TEST_FLT_NAN_ANY(tan(F(INFINITY))); \
    TEST_FLT_NAN_ANY(tan(F(-INFINITY))); \
    TEST_FLT_NAN(tan(F(NAN)), F(NAN)); \
    TEST_FLT_NAN(tan(-F(NAN)), -F(NAN))

    TEST_TAN(tan);
    TEST_TAN(tanf);
    TEST_TAN(tanl);

#define TEST_ACOS(acos) \
    TEST_FLT_ACCURACY(acos(F(1.0)), 0.0, 0.01); \
    TEST_FLT_ACCURACY(acos(F(0.0)), 3.141592654/2, 0.01); \
    TEST_FLT_ACCURACY(acos(F(-1.0)), 3.141592654, 0.01); \
    TEST_FLT_NAN_ANY(acos(F(1.1))); \
    TEST_FLT_NAN_ANY(acos(F(-1.1))); \
    TEST_FLT_NAN_ANY(acos(F(INFINITY))); \
    TEST_FLT_NAN_ANY(acos(F(-INFINITY))); \
    TEST_FLT_NAN(acos(F(NAN)), F(NAN)); \
    /* TEST_FLT_NAN(acos(-F(NAN)), -F(NAN)) - This fails on glibc/x86_64 for acosl */

    TEST_ACOS(acos);
    TEST_ACOS(acosf);
    TEST_ACOS(acosl);

#define TEST_ASIN(asin) \
    TEST_FLT_ACCURACY(asin(F(0.0)), 0.0, 0.01); \
    TEST_FLT_ACCURACY(asin(F(1.0)), 3.141592654/2, 0.01); \
    TEST_FLT_ACCURACY(asin(F(-1.0)), -3.141592654/2, 0.01); \
    TEST_FLT_NAN_ANY(asin(F(1.1))); \
    TEST_FLT_NAN_ANY(asin(F(-1.1))); \
    TEST_FLT_NAN_ANY(asin(F(INFINITY))); \
    TEST_FLT_NAN_ANY(asin(F(-INFINITY))); \
    TEST_FLT_NAN(asin(F(NAN)), F(NAN)); \
    TEST_FLT_NAN(asin(-F(NAN)), -F(NAN))

    TEST_ASIN(asin);
    TEST_ASIN(asinf);
    TEST_ASIN(asinl);

#define TEST_ATAN(atan) \
    TEST_FLT_ACCURACY(atan(F(0.0)), 0.0, 0.01); \
    TEST_FLT_ACCURACY(atan(F(1.0)), 3.141592654/4, 0.01); \
    TEST_FLT_ACCURACY(atan(F(-1.0)), -3.141592654/4, 0.01); \
    TEST_FLT_ACCURACY(atan(F(INFINITY)), 3.141592654/2, 0.01); \
    TEST_FLT_ACCURACY(atan(F(-INFINITY)), -3.141592654/2, 0.01); \
    TEST_FLT_NAN(atan(F(NAN)), F(NAN)); \
    TEST_FLT_NAN(atan(-F(NAN)), -F(NAN))

    TEST_ATAN(atan);
    TEST_ATAN(atanf);
    TEST_ATAN(atanl);

#define TEST_ATAN2(atan2) \
    TEST_FLT_ACCURACY(atan2(F(0.0), F(-1.0)), 3.141592654, 0.01); \
    TEST_FLT_SIGN(atan2(F(0.0), F(1.0)), 0.0); \
    TEST_FLT_SIGN(atan2(F(-0.0), F(1.0)), -0.0); \
    TEST_FLT_ACCURACY(atan2(F(-1.0), F(0.0)), -3.141592654/2, 0.01); \
    TEST_FLT_ACCURACY(atan2(F(1.0), F(0.0)), 3.141592654/2, 0.01); \
    TEST_FLT_SIGN(atan2(F(0.0), F(0.0)), 0.0); \
    TEST_FLT_ACCURACY(atan2(F(0.0), F(-0.0)), 3.141592654, 0.01); \
    TEST_FLT_SIGN(atan2(F(-0.0), F(0.0)), -0.0); \
    TEST_FLT_ACCURACY(atan2(F(-0.0), F(-0.0)), -3.141592654, 0.01); \
    TEST_FLT_ACCURACY(atan2(F(1.0), F(-INFINITY)), 3.141592654, 0.01); \
    TEST_FLT_ACCURACY(atan2(F(-1.0), F(-INFINITY)), -3.141592654, 0.01); \
    TEST_FLT_ACCURACY(atan2(F(1.0), F(INFINITY)), 0.0, 0.01); \
    TEST_FLT_ACCURACY(atan2(F(INFINITY), F(1.0)), 3.141592654/2, 0.01); \
    TEST_FLT_ACCURACY(atan2(F(-INFINITY), F(1.0)), -3.141592654/2, 0.01); \
    TEST_FLT_ACCURACY(atan2(F(INFINITY), F(-INFINITY)), 3*3.141592654/4, 0.01); \
    TEST_FLT_ACCURACY(atan2(F(-INFINITY), F(-INFINITY)), -3*3.141592654/4, 0.01); \
    TEST_FLT_ACCURACY(atan2(F(INFINITY), F(INFINITY)), 3.141592654/4, 0.01); \
    TEST_FLT_ACCURACY(atan2(F(-INFINITY), F(INFINITY)), -3.141592654/4, 0.01); \
    TEST_FLT_NAN_ANY(atan2(F(NAN), F(1.0))); \
    TEST_FLT_NAN_ANY(atan2(F(1.0), F(NAN)))

    TEST_ATAN2(atan2);
    TEST_ATAN2(atan2f);
    TEST_ATAN2(atan2l);

#if defined(__linux__) || defined(__MINGW32__)
    double outSin = 42.0, outCos = 42.0;
    float outSinf = 42.0, outCosf = 42.0;
    long double outSinl = 42.0, outCosl = 42.0;
#define TEST_SINCOS(sincos, outSin, outCos) \
    sincos(F(0.0), &outSin, &outCos); \
    TEST_FLT_ACCURACY(outSin, 0.0, 0.01); \
    TEST_FLT_ACCURACY(outCos, 1.0, 0.01)

    TEST_SINCOS(sincos, outSin, outCos);
    TEST_SINCOS(sincosf, outSinf, outCosf);
    TEST_SINCOS(sincosl, outSinl, outCosl);
#endif

#define TEST_ACOSH(acosh) \
    TEST_FLT_ACCURACY(acosh(F(1.0)), 0.0, 0.01); \
    TEST_FLT_ACCURACY(acosh(F(2.0)), 1.316958, 0.01); \
    TEST_FLT_NAN_ANY(acosh(F(0.0))); \
    TEST_FLT_NAN_ANY(acosh(F(-4.0))); \
    TEST_FLT_NAN_ANY(acosh(F(-INFINITY))); \
    TEST_FLT(acosh(F(INFINITY)), INFINITY); \
    TEST_FLT_NAN(acosh(F(NAN)), F(NAN)); \
    TEST_FLT_NAN(acosh(-F(NAN)), -F(NAN))

    TEST_ACOSH(acosh);
    TEST_ACOSH(acoshf);
    TEST_ACOSH(acoshl);

#define TEST_ASINH(asinh) \
    TEST_FLT_ACCURACY(asinh(F(0.0)), 0.0, 0.01); \
    TEST_FLT_ACCURACY(asinh(F(1.0)), 0.881374, 0.01); \
    TEST_FLT_ACCURACY(asinh(F(2.0)), 1.443636, 0.01); \
    TEST_FLT_ACCURACY(asinh(F(-1.0)), -0.881374, 0.01); \
    TEST_FLT_ACCURACY(asinh(F(-2.0)), -1.443636, 0.01); \
    TEST_FLT(asinh(F(INFINITY)), INFINITY); \
    TEST_FLT(asinh(F(-INFINITY)), -INFINITY); \
    TEST_FLT_NAN(asinh(F(NAN)), F(NAN)); \
    TEST_FLT_NAN(asinh(-F(NAN)), -F(NAN))

    TEST_ASINH(asinh);
    TEST_ASINH(asinhf);
    TEST_ASINH(asinhl);

#define TEST_ATANH(atanh) \
    TEST_FLT_ACCURACY(atanh(F(0.0)), 0.0, 0.01); \
    TEST_FLT_ACCURACY(atanh(F(0.5)), 0.549307, 0.01); \
    TEST_FLT_ACCURACY(atanh(F(-0.5)), -0.549307, 0.01); \
    TEST_FLT(atanh(F(1.0)), INFINITY); \
    TEST_FLT(atanh(F(-1.0)), -INFINITY); \
    TEST_FLT_NAN_ANY(atanh(F(2.0))); \
    TEST_FLT_NAN_ANY(atanh(F(-2.0))); \
    TEST_FLT_NAN(atanh(F(NAN)), F(NAN)); \
    TEST_FLT_NAN(atanh(-F(NAN)), -F(NAN))

    TEST_ATANH(atanh);
    TEST_ATANH(atanhf);
    TEST_ATANH(atanhl);

#define TEST_COSH(cosh) \
    TEST_FLT_ACCURACY(cosh(F(0.0)), 1.0, 0.01); \
    TEST_FLT_ACCURACY(cosh(F(1.316958)), 2.0, 0.01); \
    TEST_FLT_ACCURACY(cosh(F(-1.316958)), 2.0, 0.01); \
    TEST_FLT(cosh(F(INFINITY)), INFINITY); \
    TEST_FLT(cosh(F(-INFINITY)), INFINITY); \
    TEST_FLT_NAN(cosh(F(NAN)), F(NAN)); \
    TEST_FLT_NAN(cosh(-F(NAN)), -F(NAN))

    TEST_COSH(cosh);
    TEST_COSH(coshf);
    TEST_COSH(coshl);

#define TEST_SINH(sinh) \
    TEST_FLT_ACCURACY(sinh(F(0.0)), 0.0, 0.01); \
    TEST_FLT_ACCURACY(sinh(F(0.881374)), 1.0, 0.01); \
    TEST_FLT_ACCURACY(sinh(F(1.443636)), 2.0, 0.01); \
    TEST_FLT_ACCURACY(sinh(F(-0.881374)), -1.0, 0.01); \
    TEST_FLT_ACCURACY(sinh(F(-1.443636)), -2.0, 0.01); \
    TEST_FLT(sinh(F(INFINITY)), INFINITY); \
    TEST_FLT(sinh(F(-INFINITY)), -INFINITY); \
    TEST_FLT_NAN(sinh(F(NAN)), F(NAN)); \
    TEST_FLT_NAN(sinh(-F(NAN)), -F(NAN))

    TEST_SINH(sinh);
    TEST_SINH(sinhf);
    TEST_SINH(sinhl);

#define TEST_TANH(tanh) \
    TEST_FLT(tanh(F(0.0)), 0.0); \
    TEST_FLT_ACCURACY(tanh(F(0.549307)), 0.5, 0.01); \
    TEST_FLT_ACCURACY(tanh(F(-0.549307)), -0.5, 0.01); \
    TEST_FLT(tanh(F(INFINITY)), 1.0); \
    TEST_FLT(tanh(F(-INFINITY)), -1.0); \
    TEST_FLT_NAN(tanh(F(NAN)), F(NAN)); \
    TEST_FLT_NAN(tanh(-F(NAN)), -F(NAN))

    TEST_TANH(tanh);
    TEST_TANH(tanhf);
    TEST_TANH(tanhl);

#define TEST_FABS(fabs, double) \
    TEST_FLT_SIGN(fabs((double)F(0.0)), 0.0); \
    TEST_FLT_SIGN(fabs((double)F(-0.0)), 0.0); \
    TEST_FLT(fabs((double)F(3.125)), 3.125); \
    TEST_FLT(fabs((double)F(-3.125)), 3.125); \
    TEST_FLT(fabs((double)F(INFINITY)), INFINITY); \
    TEST_FLT(fabs((double)F(-INFINITY)), INFINITY); \
    TEST_FLT_NAN(fabs((double)F(NAN)), F(NAN)); \
    TEST_FLT_NAN(fabs((double)-F(NAN)), F(NAN))

    TEST_FABS(fabs, double);
    TEST_FABS(fabsf, float);
    TEST_FABS(fabsl, long double);

#define TEST_ERF(erf) \
    TEST_FLT(erf(F(0.0)), 0.0); \
    TEST_FLT_ACCURACY(erf(F(1.0)), 0.842701, 0.001); \
    TEST_FLT_ACCURACY(erf(F(-1.0)), -0.842701, 0.001); \
    TEST_FLT_ACCURACY(erf(F(2.0)), 0.995322, 0.001); \
    TEST_FLT_ACCURACY(erf(F(-2.0)), -0.995322, 0.001); \
    TEST_FLT(erf(F(INFINITY)), 1.0); \
    TEST_FLT(erf(F(-INFINITY)), -1.0); \
    TEST_FLT_NAN(erf(F(NAN)), F(NAN)); \
    TEST_FLT_NAN(erf(-F(NAN)), -F(NAN))

    TEST_ERF(erf);
    TEST_ERF(erff);
    TEST_ERF(erfl);

#define TEST_ERFC(erfc) \
    TEST_FLT(erfc(F(0.0)), 1.0); \
    TEST_FLT_ACCURACY(erfc(F(1.0)), 0.157299, 0.001); \
    TEST_FLT_ACCURACY(erfc(F(-1.0)), 1.842701, 0.001); \
    TEST_FLT_ACCURACY(erfc(F(2.0)), 0.004678, 0.001); \
    TEST_FLT_ACCURACY(erfc(F(-2.0)), 1.995322, 0.001); \
    TEST_FLT(erfc(F(INFINITY)), 0.0); \
    TEST_FLT(erfc(F(-INFINITY)), 2.0); \
    TEST_FLT_NAN(erfc(F(NAN)), F(NAN)); \
    TEST_FLT_NAN(erfc(-F(NAN)), -F(NAN))

    TEST_ERFC(erfc);
    TEST_ERFC(erfcf);
    TEST_ERFC(erfcl);

#define TEST_TGAMMA(tgamma, HUGE_VAL) \
    TEST_FLT(tgamma(F(0.0)), HUGE_VAL); \
    TEST_FLT(tgamma(F(-0.0)), -HUGE_VAL); \
    TEST_FLT_ACCURACY(tgamma(F(0.5)), 1.772454, 0.001); \
    TEST_FLT(tgamma(F(1.0)), 1.0); \
    TEST_FLT_ACCURACY(tgamma(F(1.5)), 0.886227, 0.001); \
    TEST_FLT(tgamma(F(2.0)), 1.0); \
    TEST_FLT_ACCURACY(tgamma(F(3.3)), 2.683437, 0.001); \
    TEST_FLT(tgamma(F(5.0)), 24.0); \
    TEST_FLT_ACCURACY(tgamma(F(-0.5)), -3.544908, 0.001); \
    TEST_FLT_NAN_ANY(tgamma(F(-1.0))); \
    TEST_FLT_ACCURACY(tgamma(F(-1.5)), 2.363272, 0.001); \
    TEST_FLT(tgamma(F(INFINITY)), INFINITY); \
    TEST_FLT_NAN_ANY(tgamma(F(-INFINITY))); \
    TEST_FLT_NAN(tgamma(F(NAN)), F(NAN)); \
    TEST_FLT_NAN(tgamma(-F(NAN)), -F(NAN))

    TEST_TGAMMA(tgamma, HUGE_VAL);
    TEST_TGAMMA(tgammaf, HUGE_VALF);
    TEST_TGAMMA(tgammal, HUGE_VALL);

#ifdef _MSC_VER
#define TEST_SIGNGAM(x) do { } while (0)
#else
#define TEST_SIGNGAM(x) do { x; signgam = 42; } while (0)
    signgam = 42;
#endif

#define TEST_LGAMMA(lgamma, HUGE_VAL) \
    TEST_FLT(lgamma(F(0.0)), INFINITY); \
    TEST_FLT(lgamma(F(-0.0)), INFINITY); \
    TEST_FLT_ACCURACY(lgamma(F(0.5)), 0.572365, 0.001); \
    TEST_SIGNGAM(TEST_INT(signgam, 1)); \
    TEST_FLT(lgamma(F(1.0)), 0.0); \
    TEST_SIGNGAM(TEST_INT(signgam, 1)); \
    TEST_FLT_ACCURACY(lgamma(F(1.5)), -0.120782, 0.001); \
    TEST_SIGNGAM(TEST_INT(signgam, 1)); \
    TEST_FLT(lgamma(F(2.0)), 0.0); \
    TEST_SIGNGAM(TEST_INT(signgam, 1)); \
    TEST_FLT_ACCURACY(lgamma(F(3.3)), 0.987099, 0.001); \
    TEST_SIGNGAM(TEST_INT(signgam, 1)); \
    TEST_FLT_ACCURACY(lgamma(F(5.0)), 3.178054, 0.001); \
    TEST_SIGNGAM(TEST_INT(signgam, 1)); \
    TEST_FLT_ACCURACY(lgamma(F(-0.5)), 1.265512, 0.001); \
    TEST_SIGNGAM(TEST_INT(signgam, -1)); \
    TEST_FLT(lgamma(F(-1.0)), HUGE_VAL); \
    TEST_SIGNGAM(TEST_INT(signgam, 1)); \
    TEST_FLT_ACCURACY(lgamma(F(-1.5)), 0.860047, 0.001); \
    TEST_SIGNGAM(TEST_INT(signgam, 1)); \
    TEST_FLT(lgamma(F(INFINITY)), INFINITY); \
    TEST_FLT(lgamma(F(-INFINITY)), INFINITY); \
    TEST_FLT_NAN(lgamma(F(NAN)), F(NAN)); \
    TEST_FLT_NAN(lgamma(-F(NAN)), -F(NAN))

    TEST_LGAMMA(lgamma, HUGE_VAL);
    TEST_LGAMMA(lgammaf, HUGE_VALF);
    TEST_LGAMMA(lgammal, HUGE_VALL);

    TEST_FLT_NAN_ANY(nan("foo"));
    TEST_FLT_NAN_ANY(nanf("foo"));
    TEST_FLT_NAN_ANY(nanl("foo"));

#define TEST_NEXTAFTER(nextafter, DBL_MAX, DBL_EPSILON) \
    TEST_FLT(nextafter(F(1.0), F(2.0)), 1.0 + DBL_EPSILON); \
    TEST_FLT(nextafter(F(INFINITY), F(INFINITY)), INFINITY); \
    TEST_FLT(nextafter(F(INFINITY), F(-INFINITY)), DBL_MAX); \
    TEST_FLT(nextafter(F(-INFINITY), F(-INFINITY)), -INFINITY); \
    TEST_FLT(nextafter(F(-INFINITY), F(INFINITY)), -DBL_MAX); \
    TEST_FLT_NAN(nextafter(F(NAN), F(0.0)), F(NAN)); \
    TEST_FLT_NAN(nextafter(F(0.0), F(NAN)), F(NAN)); \
    TEST_FLT_NAN(nextafter(-F(NAN), F(0.0)), -F(NAN)); \
    TEST_FLT_NAN(nextafter(F(0.0), -F(NAN)), -F(NAN))

    TEST_NEXTAFTER(nextafter, DBL_MAX, DBL_EPSILON);
    TEST_NEXTAFTER(nextafterf, FLT_MAX, FLT_EPSILON);
    TEST_NEXTAFTER(nextafterl, LDBL_MAX, LDBL_EPSILON);
    TEST_NEXTAFTER(nexttoward, DBL_MAX, DBL_EPSILON);
    TEST_NEXTAFTER(nexttowardf, FLT_MAX, FLT_EPSILON);
    TEST_NEXTAFTER(nexttowardl, LDBL_MAX, LDBL_EPSILON);

#define TEST_FDIM(fdim) \
    TEST_FLT(fdim(F(2.0), F(1.0)), 1.0); \
    TEST_FLT(fdim(F(1.0), F(2.0)), 0.0); \
    TEST_FLT(fdim(F(INFINITY), F(1.0)), INFINITY); \
    TEST_FLT(fdim(F(1.0), F(-INFINITY)), INFINITY); \
    TEST_FLT(fdim(F(-1.0), F(INFINITY)), 0.0); \
    TEST_FLT(fdim(F(-INFINITY), F(1.0)), 0.0); \
    TEST_FLT(fdim(F(-INFINITY), F(INFINITY)), 0.0); \
    TEST_FLT(fdim(F(INFINITY), F(-INFINITY)), INFINITY); \
    TEST_FLT_NAN(fdim(F(NAN), F(0.0)), F(NAN)); \
    TEST_FLT_NAN(fdim(F(0.0), F(NAN)), F(NAN)); \
    TEST_FLT_NAN(fdim(-F(NAN), F(0.0)), -F(NAN)); \
    TEST_FLT_NAN(fdim(F(0.0), -F(NAN)), -F(NAN))

    TEST_FDIM(fdim);
    TEST_FDIM(fdimf);
    TEST_FDIM(fdiml);

#define TEST_FMAX(fmax) \
    TEST_FLT(fmax(F(1.0), F(0.0)), 1.0); \
    TEST_FLT(fmax(F(0.0), F(1.0)), 1.0); \
    TEST_FLT(fmax(F(INFINITY), F(1.0)), INFINITY); \
    TEST_FLT(fmax(F(-INFINITY), F(1.0)), 1.0); \
    TEST_FLT(fmax(F(1.0), F(INFINITY)), INFINITY); \
    TEST_FLT(fmax(F(1.0), F(-INFINITY)), 1.0); \
    TEST_FLT(fmax(F(1.0), F(NAN)), 1.0); \
    TEST_FLT(fmax(F(NAN), F(1.0)), 1.0); \
    TEST_FLT_NAN_ANY(fmax(F(NAN), -F(NAN)))

    TEST_FMAX(fmax);
    TEST_FMAX(fmaxf);
    TEST_FMAX(fmaxl);

#define TEST_FMIN(fmin) \
    TEST_FLT(fmin(F(1.0), F(0.0)), 0.0); \
    TEST_FLT(fmin(F(0.0), F(1.0)), 0.0); \
    TEST_FLT(fmin(F(0.0), F(-1.0)), -1.0); \
    TEST_FLT(fmin(F(-1.0), F(0.0)), -1.0); \
    TEST_FLT(fmin(F(INFINITY), F(1.0)), 1.0); \
    TEST_FLT(fmin(F(-INFINITY), F(1.0)), -INFINITY); \
    TEST_FLT(fmin(F(1.0), F(INFINITY)), 1.0); \
    TEST_FLT(fmin(F(1.0), F(-INFINITY)), -INFINITY); \
    TEST_FLT(fmin(F(1.0), F(NAN)), 1.0); \
    TEST_FLT(fmin(F(NAN), F(1.0)), 1.0); \
    TEST_FLT_NAN_ANY(fmin(F(NAN), -F(NAN)))

    TEST_FMIN(fmin);
    TEST_FMIN(fminf);
    TEST_FMIN(fminl);

    TEST_INT(isgreater(F(0.0), F(0.0)), 0);
    TEST_INT(isgreater(F(1.0), F(0.0)), 1);
    TEST_INT(isgreater(F(0.0), F(1.0)), 0);
    TEST_INT(isgreater(F(INFINITY), F(0.0)), 1);
    TEST_INT(isgreater(F(-INFINITY), F(0.0)), 0);
    TEST_INT(isgreater(F(0.0), F(INFINITY)), 0);
    TEST_INT(isgreater(F(0.0), F(-INFINITY)), 1);
    TEST_INT(isgreater(F(0.0), F(NAN)), 0);
    TEST_INT(isgreater(F(NAN), F(0.0)), 0);
    TEST_INT(isgreater(F(NAN), F(NAN)), 0);

    TEST_INT(isgreaterequal(F(0.0), F(0.0)), 1);
    TEST_INT(isgreaterequal(F(1.0), F(0.0)), 1);
    TEST_INT(isgreaterequal(F(0.0), F(1.0)), 0);
    TEST_INT(isgreaterequal(F(INFINITY), F(0.0)), 1);
    TEST_INT(isgreaterequal(F(-INFINITY), F(0.0)), 0);
    TEST_INT(isgreaterequal(F(0.0), F(INFINITY)), 0);
    TEST_INT(isgreaterequal(F(0.0), F(-INFINITY)), 1);
    TEST_INT(isgreaterequal(F(0.0), F(NAN)), 0);
    TEST_INT(isgreaterequal(F(NAN), F(0.0)), 0);
    TEST_INT(isgreaterequal(F(NAN), F(NAN)), 0);

    TEST_INT(isless(F(0.0), F(0.0)), 0);
    TEST_INT(isless(F(1.0), F(0.0)), 0);
    TEST_INT(isless(F(0.0), F(1.0)), 1);
    TEST_INT(isless(F(INFINITY), F(0.0)), 0);
    TEST_INT(isless(F(-INFINITY), F(0.0)), 1);
    TEST_INT(isless(F(0.0), F(INFINITY)), 1);
    TEST_INT(isless(F(0.0), F(-INFINITY)), 0);
    TEST_INT(isless(F(0.0), F(NAN)), 0);
    TEST_INT(isless(F(NAN), F(0.0)), 0);
    TEST_INT(isless(F(NAN), F(NAN)), 0);

    TEST_INT(islessequal(F(0.0), F(0.0)), 1);
    TEST_INT(islessequal(F(1.0), F(0.0)), 0);
    TEST_INT(islessequal(F(0.0), F(1.0)), 1);
    TEST_INT(islessequal(F(INFINITY), F(0.0)), 0);
    TEST_INT(islessequal(F(-INFINITY), F(0.0)), 1);
    TEST_INT(islessequal(F(0.0), F(INFINITY)), 1);
    TEST_INT(islessequal(F(0.0), F(-INFINITY)), 0);
    TEST_INT(islessequal(F(0.0), F(NAN)), 0);
    TEST_INT(islessequal(F(NAN), F(0.0)), 0);
    TEST_INT(islessequal(F(NAN), F(NAN)), 0);

    TEST_INT(islessgreater(F(0.0), F(0.0)), 0);
    TEST_INT(islessgreater(F(1.0), F(0.0)), 1);
    TEST_INT(islessgreater(F(0.0), F(1.0)), 1);
    TEST_INT(islessgreater(F(INFINITY), F(0.0)), 1);
    TEST_INT(islessgreater(F(-INFINITY), F(0.0)), 1);
    TEST_INT(islessgreater(F(0.0), F(INFINITY)), 1);
    TEST_INT(islessgreater(F(0.0), F(-INFINITY)), 1);
    TEST_INT(islessgreater(F(0.0), F(NAN)), 0);
    TEST_INT(islessgreater(F(NAN), F(0.0)), 0);
    TEST_INT(islessgreater(F(NAN), F(NAN)), 0);

    TEST_INT(isunordered(F(0.0), F(0.0)), 0);
    TEST_INT(isunordered(F(1.0), F(0.0)), 0);
    TEST_INT(isunordered(F(0.0), F(1.0)), 0);
    TEST_INT(isunordered(F(INFINITY), F(0.0)), 0);
    TEST_INT(isunordered(F(-INFINITY), F(0.0)), 0);
    TEST_INT(isunordered(F(0.0), F(INFINITY)), 0);
    TEST_INT(isunordered(F(0.0), F(-INFINITY)), 0);
    TEST_INT(isunordered(F(0.0), F(NAN)), 1);
    TEST_INT(isunordered(F(NAN), F(0.0)), 1);
    TEST_INT(isunordered(F(NAN), F(NAN)), 1);

#define TEST_COPYSIGN(copysign) \
    TEST_FLT_ACCURACY(copysign(F(3.125), F(1)), 3.125, 0.0001); \
    TEST_FLT_ACCURACY(copysign(F(3.125), F(-1)), -3.125, 0.0001); \
    TEST_FLT_ACCURACY(copysign(F(-3.125), F(-1)), -3.125, 0.0001); \
    TEST_FLT_ACCURACY(copysign(F(-3.125), F(1)), 3.125, 0.0001); \
    TEST_FLT_ACCURACY(copysign(F(3.125), -F(NAN)), -3.125, 0.0001); \
    TEST_FLT(copysign(F(INFINITY), F(1)), INFINITY); \
    TEST_FLT(copysign(F(INFINITY), F(-1)), -INFINITY); \
    TEST_FLT(copysign(F(-INFINITY), F(-1)), -INFINITY); \
    TEST_FLT(copysign(F(-INFINITY), F(1)), INFINITY); \
    TEST_FLT_NAN(copysign(F(NAN), F(-1)), -F(NAN)); \
    TEST_FLT_NAN(copysign(-F(NAN), F(NAN)), F(NAN))

    TEST_COPYSIGN(copysign);
    TEST_COPYSIGN(copysignf);
    TEST_COPYSIGN(copysignl);

#ifdef _WIN32
    TEST_COPYSIGN(_copysign);
    TEST_COPYSIGN(_copysignf);
    TEST_COPYSIGN(_copysignl);

    TEST_FLT_ACCURACY(_chgsignl(F(3.125)), -3.125, 0.0001);
    TEST_FLT_ACCURACY(_chgsignl(F(-3.125)), 3.125, 0.0001);
    TEST_FLT(_chgsignl(F(INFINITY)), -INFINITY);
    TEST_FLT(_chgsignl(F(-INFINITY)), INFINITY);
    TEST_FLT_NAN(_chgsignl(F(NAN)), -F(NAN));
    TEST_FLT_NAN(_chgsignl(-F(NAN)), F(NAN));
#endif

    TEST_INT(L(7) / L(7), 1); // __rt_sdiv
    TEST_INT(L(-7) / L(7), -1); // __rt_sdiv
    TEST_INT(L(-7) / L(-7), 1); // __rt_sdiv
    TEST_INT(L(7) / L(-7), -1); // __rt_sdiv
    TEST_INT(L(1073741824) / L(3), 357913941); // __rt_sdiv
    TEST_INT(L(0) / L(3), 0); // __rt_sdiv
    TEST_INT(L(0) / L(-3), 0); // __rt_sdiv
    TEST_INT(L(1024) / L(357913941), 0); // __rt_sdiv
    TEST_INT(L(1073741824) / L(357913941), 3); // __rt_sdiv
    TEST_INT(L(2147483647) / L(1), 2147483647); // __rt_sdiv
    TEST_INT(L(2147483647) / L(-1), -2147483647); // __rt_sdiv
    TEST_INT(L(-2147483648) / L(1), (long) -2147483648LL); // __rt_sdiv

    TEST_INT(UL(7) / L(7), 1); // __rt_udiv
    TEST_INT(UL(4294967289) / L(7), 613566755); // __rt_udiv
    TEST_INT(UL(4294967289) / L(1), 4294967289UL); // __rt_udiv
    TEST_INT(UL(1073741824) / L(3), 357913941); // __rt_udiv
    TEST_INT(UL(0) / L(3), 0); // __rt_udiv
    TEST_INT(UL(1024) / L(357913941), 0); // __rt_udiv
    TEST_INT(UL(1073741824) / L(357913941), 3); // __rt_udiv
    TEST_INT(UL(2147483647) / L(1), 2147483647); // __rt_udiv

    TEST_INT(LL(7) / 7, 1); // __rt_sdiv64
    TEST_INT(LL(-7) / 7, -1); // __rt_sdiv64
    TEST_INT(LL(-7) / -7, 1); // __rt_sdiv64
    TEST_INT(LL(7) / -7, -1); // __rt_sdiv64
    TEST_INT(LL(1073741824) / 3, 357913941); // __rt_sdiv64
    TEST_INT(LL(0) / 3, 0); // __rt_sdiv64
    TEST_INT(LL(0) / -3, 0); // __rt_sdiv64
    TEST_INT(LL(1024) / 357913941, 0); // __rt_sdiv64
    TEST_INT(LL(1073741824) / 357913941, 3); // __rt_sdiv64
    TEST_INT(LL(2147483647) / LL(1), 2147483647); // __rt_sdiv64
    TEST_INT(LL(2147483647) / LL(-1), -2147483647); // __rt_sdiv64
    TEST_INT(LL(-2147483648) / LL(1), -2147483648LL); // __rt_sdiv64
    TEST_INT(LL(0) / LL(2305843009213693952), 0); // __rt_sdiv64
    TEST_INT(LL(0) / LL(2305843009213693953), 0); // __rt_sdiv64
    TEST_INT(LL(0) / LL(2147483648), 0); // __rt_sdiv64
    TEST_INT(LL(0) / LL(4294967296), 0); // __rt_sdiv64
    TEST_INT(LL(4294967296) / LL(4294967296), 1); // __rt_sdiv64
    TEST_INT(LL(4294967295) / LL(4294967296), 0); // __rt_sdiv64
    TEST_INT(LL(883547321287490176) / LL(128), 6902713447558517LL); // __rt_sdiv64

    TEST_INT(ULL(7) / 7, 1); // __rt_udiv64
    TEST_INT(ULL(4294967289) / LL(7), 613566755); // __rt_udiv64
    TEST_INT(ULL(4294967289) / LL(1), 4294967289ULL); // __rt_udiv64
    TEST_INT(ULL(1073741824) / LL(3), 357913941); // __rt_udiv64
    TEST_INT(ULL(0) / LL(3), 0); // __rt_udiv64
    TEST_INT(ULL(1024) / LL(357913941), 0); // __rt_udiv64
    TEST_INT(ULL(1073741824) / LL(357913941), 3); // __rt_udiv64
    TEST_INT(ULL(2147483647) / LL(1), 2147483647); // __rt_udiv64
    TEST_INT(ULL(18446744073709551615) / LL(1), 18446744073709551615ULL); // __rt_udiv64
    TEST_INT(ULL(0) / ULL(2305843009213693952), 0); // __rt_udiv64
    TEST_INT(ULL(0) / ULL(2305843009213693953), 0); // __rt_udiv64
    TEST_INT(ULL(0) / ULL(2147483648), 0); // __rt_udiv64
    TEST_INT(ULL(0) / ULL(4294967296), 0); // __rt_udiv64
    TEST_INT(ULL(4294967296) / ULL(4294967296), 1); // __rt_udiv64
    TEST_INT(ULL(4294967297) / ULL(8589934593), 0); // __rt_udiv64
    TEST_INT(ULL(883547321287490176) / ULL(128), 6902713447558517ULL); // __rt_udiv64


    TEST_INT(L(7) % L(7), 0); // __rt_sdiv
    TEST_INT(L(-7) % L(7), 0); // __rt_sdiv
    TEST_INT(L(-7) % L(-7), 0); // __rt_sdiv
    TEST_INT(L(7) % L(-7), 0); // __rt_sdiv
    TEST_INT(L(1073741824) % L(3), 1); // __rt_sdiv
    TEST_INT(L(0) % L(3), 0); // __rt_sdiv
    TEST_INT(L(0) % L(-3), 0); // __rt_sdiv
    TEST_INT(L(1024) % L(357913941), 1024); // __rt_sdiv
    TEST_INT(L(1073741824) % L(357913941), 1); // __rt_sdiv
    TEST_INT(L(2147483647) % L(1), 0); // __rt_sdiv
    TEST_INT(L(2147483647) % L(-1), 0); // __rt_sdiv
    TEST_INT(L(-2147483648) % L(1), 0); // __rt_sdiv

    TEST_INT(UL(7) % L(7), 0); // __rt_udiv
    TEST_INT(UL(4294967289) % L(7), 4); // __rt_udiv
    TEST_INT(UL(4294967289) % L(1), 0); // __rt_udiv
    TEST_INT(UL(1073741824) % L(3), 1); // __rt_udiv
    TEST_INT(UL(0) % L(3), 0); // __rt_udiv
    TEST_INT(UL(1024) % L(357913941), 1024); // __rt_udiv
    TEST_INT(UL(1073741824) % L(357913941), 1); // __rt_udiv
    TEST_INT(UL(2147483647) % L(1), 0); // __rt_udiv

    TEST_INT(LL(7) % 7, 0); // __rt_sdiv64
    TEST_INT(LL(-7) % 7, 0); // __rt_sdiv64
    TEST_INT(LL(-7) % -7, 0); // __rt_sdiv64
    TEST_INT(LL(7) % -7, 0); // __rt_sdiv64
    TEST_INT(LL(1073741824) % 3, 1); // __rt_sdiv64
    TEST_INT(LL(0) % 3, 0); // __rt_sdiv64
    TEST_INT(LL(0) % -3, 0); // __rt_sdiv64
    TEST_INT(LL(1024) % 357913941, 1024); // __rt_sdiv64
    TEST_INT(LL(1073741824) % 357913941, 1); // __rt_sdiv64
    TEST_INT(LL(2147483647) % LL(1), 0); // __rt_sdiv64
    TEST_INT(LL(2147483647) % LL(-1), 0); // __rt_sdiv64
    TEST_INT(LL(-2147483648) % LL(1), 0); // __rt_sdiv64
    TEST_INT(LL(0) % LL(2305843009213693952), 0); // __rt_sdiv64
    TEST_INT(LL(0) % LL(2305843009213693953), 0); // __rt_sdiv64
    TEST_INT(LL(0) % LL(2147483648), 0); // __rt_sdiv64
    TEST_INT(LL(0) % LL(4294967296), 0); // __rt_sdiv64
    TEST_INT(LL(4294967296) % LL(4294967296), 0); // __rt_sdiv64
    TEST_INT(LL(4294967295) % LL(4294967296), 4294967295LL); // __rt_sdiv64

    TEST_INT(ULL(7) % 7, 0); // __rt_udiv64
    TEST_INT(ULL(4294967289) % LL(7), 4); // __rt_udiv64
    TEST_INT(ULL(4294967289) % LL(1), 0); // __rt_udiv64
    TEST_INT(ULL(1073741824) % LL(3), 1); // __rt_udiv64
    TEST_INT(ULL(0) % LL(3), 0); // __rt_udiv64
    TEST_INT(ULL(1024) % LL(357913941), 1024); // __rt_udiv64
    TEST_INT(ULL(1073741824) % LL(357913941), 1); // __rt_udiv64
    TEST_INT(ULL(2147483647) % LL(1), 0); // __rt_udiv64
    TEST_INT(ULL(18446744073709551615) % LL(1), 0); // __rt_udiv64
    TEST_INT(ULL(0) % ULL(2305843009213693952), 0); // __rt_udiv64
    TEST_INT(ULL(0) % ULL(2305843009213693953), 0); // __rt_udiv64
    TEST_INT(ULL(0) % ULL(2147483648), 0); // __rt_udiv64
    TEST_INT(ULL(0) % ULL(4294967296), 0); // __rt_udiv64
    TEST_INT(ULL(4294967296) % ULL(4294967296), 0); // __rt_udiv64
    TEST_INT(ULL(4294967297) % ULL(8589934593), 4294967297ULL); // __rt_udiv64

    TEST_INT((unsigned long long)F(4.2), 4);
    TEST_INT((signed long long)F(4.2), 4);
    TEST_INT((unsigned long long)F(123456789012345678), 123456789012345680ULL);
    TEST_INT((signed long long)F(123456789012345678), 123456789012345680ULL);
    TEST_INT((signed long long)F(-123456789012345), -123456789012345LL);

    TEST_INT((unsigned long long)(float)F(4.2), 4);
    TEST_INT((signed long long)(float)F(4.2), 4);
    TEST_INT((unsigned long long)(float)F(274877906944), 274877906944ULL);
    TEST_INT((signed long long)(float)F(274877906944), 274877906944ULL);
    TEST_INT((signed long long)(float)F(-274877906944), -274877906944LL);

    TEST_FLT((double)LL(4), 4.0);
    TEST_FLT((float)LL(4), 4.0);
    TEST_FLT((double)LL(123456789012345), 123456789012345.0);
    TEST_FLT((double)LL(-123456789012345), -123456789012345.0);
    TEST_FLT((float)LL(274877906944), 274877906944.0);
    TEST_FLT((float)LL(-274877906944), -274877906944.0);

    TEST_FLT((double)ULL(4), 4.0);
    TEST_FLT((float)ULL(4), 4.0);
    TEST_FLT((double)ULL(17293822569102704640), 17293822569102704640.0);
    TEST_FLT((float)ULL(17293822569102704640), 17293822569102704640.0);

#ifdef _WIN32
    long value = 0;
    __int64 ret;
    __int64 value64 = 0;
    void *ptr = NULL;
    void *ptr1 = &value;
    void *ptr2 = &value64;
    void *ret_ptr;
#define TEST_FUNC(expr, var, expected, expected_ret) do { \
        ret = expr; \
        TEST_INT(var, expected); \
        TEST_INT(ret, expected_ret); \
        var = expected; \
    } while (0)
#define TEST_FUNC_PTR(expr, var, expected, expected_ret) do { \
        ret_ptr = expr; \
        TEST_PTR(var, expected); \
        TEST_PTR(ret_ptr, expected_ret); \
        var = expected; \
    } while (0)
    TEST_FUNC(InterlockedBitTestAndSet(&value, 0), value, 1, 0);
    TEST_FUNC(InterlockedBitTestAndSet(&value, 2), value, 5, 0);
    TEST_FUNC(InterlockedBitTestAndSet(&value, 2), value, 5, 1);
    TEST_FUNC(InterlockedBitTestAndReset(&value, 2), value, 1, 1);
    TEST_FUNC(InterlockedBitTestAndReset(&value, 2), value, 1, 0);
    TEST_FUNC(InterlockedBitTestAndReset(&value, 0), value, 0, 1);
#ifdef _WIN64
    TEST_FUNC(InterlockedBitTestAndSet64(&value64, 0), value64, 1, 0);
    TEST_FUNC(InterlockedBitTestAndSet64(&value64, 2), value64, 5, 0);
    TEST_FUNC(InterlockedBitTestAndSet64(&value64, 2), value64, 5, 1);
    TEST_FUNC(InterlockedBitTestAndSet64(&value64, 40), value64, 0x10000000005, 0);
    TEST_FUNC(InterlockedBitTestAndReset64(&value64, 40), value64, 5, 1);
    TEST_FUNC(InterlockedBitTestAndReset64(&value64, 2), value64, 1, 1);
    TEST_FUNC(InterlockedBitTestAndReset64(&value64, 2), value64, 1, 0);
    TEST_FUNC(InterlockedBitTestAndReset64(&value64, 0), value64, 0, 1);
#endif
    TEST_FUNC(InterlockedIncrement(&value), value, 1, 1);
    TEST_FUNC(InterlockedDecrement(&value), value, 0, 0);
    TEST_FUNC(InterlockedAdd(&value, 7), value, 7, 7);
    TEST_FUNC(InterlockedAdd(&value, -2), value, 5, 5);
    TEST_FUNC(InterlockedAdd64(&value64, 7), value64, 7, 7);
    TEST_FUNC(InterlockedAdd64(&value64, 0x10000000000), value64, 0x10000000007, 0x10000000007);
    TEST_FUNC(InterlockedIncrement64(&value64), value64, 0x10000000008, 0x10000000008);
    TEST_FUNC(InterlockedDecrement64(&value64), value64, 0x10000000007, 0x10000000007);
    TEST_FUNC(InterlockedAdd64(&value64, -0x10000000002), value64, 5, 5);
    // Exchange functions return the previous value
    TEST_FUNC(InterlockedExchangeAdd(&value, 1), value, 6, 5);
    TEST_FUNC(InterlockedExchange(&value, 2), value, 2, 6);
    TEST_FUNC(InterlockedCompareExchange(&value, 7, 1), value, 2, 2);
    TEST_FUNC(InterlockedCompareExchange(&value, 5, 2), value, 5, 2);
    TEST_FUNC_PTR(InterlockedExchangePointer(&ptr, ptr1), ptr, ptr1, NULL);
    TEST_FUNC_PTR(InterlockedExchangePointer(&ptr, ptr2), ptr, ptr2, ptr1);
    TEST_FUNC_PTR(InterlockedCompareExchangePointer(&ptr, NULL, ptr1), ptr, ptr2, ptr2);
    TEST_FUNC_PTR(InterlockedCompareExchangePointer(&ptr, NULL, ptr2), ptr, NULL, ptr2);
    TEST_FUNC(InterlockedExchangeAdd64(&value64, 0x10000000000), value64, 0x10000000005, 5);
    TEST_FUNC(InterlockedExchange64(&value64, 0x10000000000), value64, 0x10000000000, 0x10000000005);
    TEST_FUNC(InterlockedCompareExchange64(&value64, 7, 1), value64, 0x10000000000, 0x10000000000);
    TEST_FUNC(InterlockedCompareExchange64(&value64, 0x20000000005, 0x10000000000), value64, 0x20000000005, 0x10000000000);
    // Logical operations returns the previous value
    TEST_FUNC(InterlockedOr(&value, 2), value, 7, 5);
    TEST_FUNC(InterlockedOr(&value, 2), value, 7, 7);
    TEST_FUNC(InterlockedAnd(&value, 2), value, 2, 7);
    TEST_FUNC(InterlockedAnd(&value, 2), value, 2, 2);
    TEST_FUNC(InterlockedXor(&value, 2), value, 0, 2);
    TEST_FUNC(InterlockedXor(&value, 2), value, 2, 0);
    TEST_FUNC(InterlockedXor(&value, 2), value, 0, 2);
    TEST_FUNC(InterlockedOr64(&value64, 2), value64, 0x20000000007, 0x20000000005);
    TEST_FUNC(InterlockedOr64(&value64, 0x10000000000), value64, 0x30000000007, 0x20000000007);
    TEST_FUNC(InterlockedAnd64(&value64, 0x20000000000), value64, 0x20000000000, 0x30000000007);
    TEST_FUNC(InterlockedAnd64(&value64, 0x20000000000), value64, 0x20000000000, 0x20000000000);
    TEST_FUNC(InterlockedXor64(&value64, 0x20000000000), value64, 0, 0x20000000000);
    TEST_FUNC(InterlockedXor64(&value64, 0x20000000000), value64, 0x20000000000, 0);
    TEST_FUNC(InterlockedXor64(&value64, 0x20000000000), value64, 0, 0x20000000000);

    unsigned long idx = 42;
    // If no bit is set, idx is set to an undefined value.
    TEST_INT(BitScanForward(&idx, UL(0)), 0);
    TEST_FUNC(BitScanForward(&idx, UL(1)), idx, 0, 1);
    TEST_FUNC(BitScanForward(&idx, UL(0x80000000)), idx, 31, 1);
    TEST_FUNC(BitScanForward(&idx, UL(0x80000001)), idx, 0, 1);
    TEST_INT(BitScanReverse(&idx, UL(0)), 0);
    TEST_FUNC(BitScanReverse(&idx, UL(1)), idx, 0, 1);
    TEST_FUNC(BitScanReverse(&idx, UL(0x80000000)), idx, 31, 1);
    TEST_FUNC(BitScanReverse(&idx, UL(0x80000001)), idx, 31, 1);
#if !defined(_M_ARM) && !defined(__arm__) && !defined(__i386__)
    // These seem to be unavailable on 32 bit arm even in MSVC. They're also missing
    // on i386 mingw.
    TEST_INT(BitScanForward64(&idx, UL(0)), 0);
    TEST_FUNC(BitScanForward64(&idx, UL(1)), idx, 0, 1);
    TEST_FUNC(BitScanForward64(&idx, UL(0x80000000)), idx, 31, 1);
    TEST_FUNC(BitScanForward64(&idx, UL(0x80000001)), idx, 0, 1);
    TEST_FUNC(BitScanForward64(&idx, ULL(0x8000000000000000)), idx, 63, 1);
    TEST_INT(BitScanReverse64(&idx, UL(0)), 0);
    TEST_FUNC(BitScanReverse64(&idx, UL(1)), idx, 0, 1);
    TEST_FUNC(BitScanReverse64(&idx, UL(0x80000000)), idx, 31, 1);
    TEST_FUNC(BitScanReverse64(&idx, UL(0x80000001)), idx, 31, 1);
    TEST_FUNC(BitScanReverse64(&idx, ULL(0x8000000000000000)), idx, 63, 1);
#endif

    // Test intrinsics versions. Not all combinations are available.
    TEST_FUNC(_interlockedbittestandset(&value, 0), value, 1, 0);
    TEST_FUNC(_interlockedbittestandset(&value, 2), value, 5, 0);
    TEST_FUNC(_interlockedbittestandset(&value, 2), value, 5, 1);
    TEST_FUNC(_interlockedbittestandreset(&value, 2), value, 1, 1);
    TEST_FUNC(_interlockedbittestandreset(&value, 2), value, 1, 0);
    TEST_FUNC(_interlockedbittestandreset(&value, 0), value, 0, 1);
    TEST_FUNC(_InterlockedIncrement(&value), value, 1, 1);
    TEST_FUNC(_InterlockedDecrement(&value), value, 0, 0);
#ifdef _WIN64
    TEST_FUNC(_interlockedbittestandset64(&value64, 0), value64, 1, 0);
    TEST_FUNC(_interlockedbittestandset64(&value64, 2), value64, 5, 0);
    TEST_FUNC(_interlockedbittestandset64(&value64, 2), value64, 5, 1);
    TEST_FUNC(_interlockedbittestandset64(&value64, 40), value64, 0x10000000005, 0);
    TEST_FUNC(_interlockedbittestandset64(&value64, 41), value64, 0x30000000005, 0);
    TEST_FUNC(_interlockedbittestandreset64(&value64, 40), value64, 0x20000000005, 1);
    TEST_FUNC(_interlockedbittestandreset64(&value64, 2), value64, 0x20000000001, 1);
    TEST_FUNC(_interlockedbittestandreset64(&value64, 2), value64, 0x20000000001, 0);
    TEST_FUNC(_interlockedbittestandreset64(&value64, 0), value64, 0x20000000000, 1);
    TEST_FUNC(_InterlockedIncrement64(&value64), value64, 0x20000000001, 0x20000000001);
    TEST_FUNC(_InterlockedDecrement64(&value64), value64, 0x20000000000, 0x20000000000);
    TEST_FUNC(_interlockedbittestandreset64(&value64, 41), value64, 0, 1);
#endif
    TEST_FUNC(_InterlockedExchangeAdd(&value, 1), value, 1, 0);
    TEST_FUNC(_InterlockedExchange(&value, 2), value, 2, 1);
    TEST_FUNC(_InterlockedCompareExchange(&value, 7, 1), value, 2, 2);
    TEST_FUNC(_InterlockedCompareExchange(&value, 0, 2), value, 0, 2);
    TEST_FUNC_PTR(_InterlockedExchangePointer(&ptr, ptr1), ptr, ptr1, NULL);
    TEST_FUNC_PTR(_InterlockedExchangePointer(&ptr, ptr2), ptr, ptr2, ptr1);
    TEST_FUNC_PTR(_InterlockedCompareExchangePointer(&ptr, NULL, ptr1), ptr, ptr2, ptr2);
    TEST_FUNC_PTR(_InterlockedCompareExchangePointer(&ptr, NULL, ptr2), ptr, NULL, ptr2);
#ifdef _WIN64
    TEST_FUNC(_InterlockedExchangeAdd64(&value64, 0x20000000000), value64, 0x20000000000, 0);
    TEST_FUNC(_InterlockedExchange64(&value64, 0x10000000000), value64, 0x10000000000, 0x20000000000);
    TEST_FUNC(_InterlockedCompareExchange64(&value64, 7, 1), value64, 0x10000000000, 0x10000000000);
    TEST_FUNC(_InterlockedCompareExchange64(&value64, 0x20000000000, 0x10000000000), value64, 0x20000000000, 0x10000000000);
#endif
    TEST_FUNC(_InterlockedOr(&value, 2), value, 2, 0);
    TEST_FUNC(_InterlockedOr(&value, 5), value, 7, 2);
    TEST_FUNC(_InterlockedAnd(&value, 2), value, 2, 7);
    TEST_FUNC(_InterlockedAnd(&value, 2), value, 2, 2);
    TEST_FUNC(_InterlockedXor(&value, 2), value, 0, 2);
    TEST_FUNC(_InterlockedXor(&value, 2), value, 2, 0);
    TEST_FUNC(_InterlockedXor(&value, 2), value, 0, 2);
#ifdef _WIN64
    TEST_FUNC(_InterlockedOr64(&value64, 0x10000000000), value64, 0x30000000000, 0x20000000000);
    TEST_FUNC(_InterlockedAnd64(&value64, 0x10000000000), value64, 0x10000000000, 0x30000000000);
    TEST_FUNC(_InterlockedXor64(&value64, 0x10000000000), value64, 0, 0x10000000000);
    TEST_FUNC(_InterlockedXor64(&value64, 0x10000000000), value64, 0x10000000000, 0);
    TEST_FUNC(_InterlockedXor64(&value64, 0x10000000000), value64, 0, 0x10000000000);
#endif

    TEST_INT(_BitScanForward(&idx, UL(0)), 0);
    TEST_FUNC(_BitScanForward(&idx, UL(1)), idx, 0, 1);
    TEST_FUNC(_BitScanForward(&idx, UL(0x80000000)), idx, 31, 1);
    TEST_FUNC(_BitScanForward(&idx, UL(0x80000001)), idx, 0, 1);
    TEST_INT(_BitScanReverse(&idx, UL(0)), 0);
    TEST_FUNC(_BitScanReverse(&idx, UL(1)), idx, 0, 1);
    TEST_FUNC(_BitScanReverse(&idx, UL(0x80000000)), idx, 31, 1);
    TEST_FUNC(_BitScanReverse(&idx, UL(0x80000001)), idx, 31, 1);
#ifdef _WIN64
    TEST_INT(_BitScanForward64(&idx, UL(0)), 0);
    TEST_FUNC(_BitScanForward64(&idx, UL(1)), idx, 0, 1);
    TEST_FUNC(_BitScanForward64(&idx, UL(0x80000000)), idx, 31, 1);
    TEST_FUNC(_BitScanForward64(&idx, UL(0x80000001)), idx, 0, 1);
    TEST_FUNC(_BitScanForward64(&idx, ULL(0x8000000000000000)), idx, 63, 1);
    TEST_INT(_BitScanReverse64(&idx, UL(0)), 0);
    TEST_FUNC(_BitScanReverse64(&idx, UL(1)), idx, 0, 1);
    TEST_FUNC(_BitScanReverse64(&idx, UL(0x80000000)), idx, 31, 1);
    TEST_FUNC(_BitScanReverse64(&idx, UL(0x80000001)), idx, 31, 1);
    TEST_FUNC(_BitScanReverse64(&idx, ULL(0x8000000000000000)), idx, 63, 1);
#endif
#endif

    printf("%d tests, %d failures\n", tests, fails);
    return fails > 0;
}
