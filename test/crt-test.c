#include <stdio.h>
#include <math.h>
#include <string.h>
#include <stdlib.h>
#include <fenv.h>
#include <inttypes.h>
#include <stdarg.h>
#ifdef _WIN32
#include <windows.h>
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
        if (strcmp(x, expect)) { \
            fails++; \
            printf("%s:%d: %sexpected \"%s\", got \"%s\"\n", __FILE__, __LINE__, context, expect, x); \
        } \
    } while (0)

#define TEST_FLT(x, expect) do { \
        tests++; \
        if (x != expect) { \
            fails++; \
            printf("%s:%d: %s%s failed, expected %f, got %f\n", __FILE__, __LINE__, context, #x, (double)expect, (double)x); \
        } \
    } while (0)

#define TEST_FLT_EXPR(x, expr) do { \
        tests++; \
        if (!(expr)) { \
            fails++; \
            printf("%s:%d: %s%s failed, got %f\n", __FILE__, __LINE__, context, #expr, (double)x); \
        } \
    } while (0)

#define TEST_FLT_NAN(x) do { \
        tests++; \
        if (!isnan(x)) { \
            fails++; \
            printf("%s:%d: %s%s failed, got %f\n", __FILE__, __LINE__, context, #x, (double)x); \
        } \
    } while (0)

#define TEST_FLT_ACCURACY(x, expect, accuracy) do { \
        long double val = x; \
        long double diff = fabsl(val - expect); \
        tests++; \
        if (diff > accuracy) { \
            fails++; \
            printf("%s:%d: %s%s failed, expected %f, got %f (diff %f > %f)\n", __FILE__, __LINE__, context, #x, (double)expect, (double)val, (double)diff, (double)accuracy); \
        } \
    } while (0)

#define TEST_INT(x, expect) do { \
        tests++; \
        if (x != expect) { \
            fails++; \
            printf("%s:%d: %s%s failed, expected %lld, got %lld\n", __FILE__, __LINE__, context, #x, (long long)expect, (long long)x); \
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

    TEST_FLT(floor(F(3.9)), 3.0);
#if !defined(__MINGW32__) || !defined(__arm__)
    // TODO: floor/ceil on mingw-w64 on arm truncates results to the 32 bit integer range
    TEST_FLT(floor(F(17179869184.0)), 17179869184.0);
#endif
    TEST_FLT(floor(F(-3.3)), -4.0);
    TEST_FLT(floor(F(-3.9)), -4.0);
    TEST_FLT(floor(F(INFINITY)), INFINITY);
    TEST_FLT(floor(F(-INFINITY)), -INFINITY);
    TEST_FLT_NAN(floor(F(NAN)));
    TEST_FLT_NAN(floor(F(-NAN)));
    TEST_FLT_NAN(floor(-F(NAN)));

    TEST_FLT(floorf(F(3.9)), 3.0);
    TEST_FLT(floorf(F(-3.3)), -4.0);
    TEST_FLT(floorf(F(-3.9)), -4.0);
    TEST_FLT(floorf(F(INFINITY)), INFINITY);
    TEST_FLT(floorf(F(-INFINITY)), -INFINITY);
    TEST_FLT_NAN(floorf(F(NAN)));
    TEST_FLT_NAN(floorf(F(-NAN)));
    TEST_FLT_NAN(floorf(-F(NAN)));

    TEST_FLT(floorl(F(3.9)), 3.0);
    TEST_FLT(floorl(F(-3.3)), -4.0);
    TEST_FLT(floorl(F(-3.9)), -4.0);
    TEST_FLT(floorl(F(INFINITY)), INFINITY);
    TEST_FLT(floorl(F(-INFINITY)), -INFINITY);
    TEST_FLT_NAN(floorl(F(NAN)));
    TEST_FLT_NAN(floorl(F(-NAN)));
    TEST_FLT_NAN(floorl(-F(NAN)));

    TEST_FLT(ceil(F(3.9)), 4.0);
    TEST_FLT(ceil(F(-3.3)), -3.0);
    TEST_FLT(ceil(F(-3.9)), -3.0);
    TEST_FLT(ceil(F(INFINITY)), INFINITY);
    TEST_FLT(ceil(F(-INFINITY)), -INFINITY);
    TEST_FLT_NAN(ceil(F(NAN)));
    TEST_FLT_NAN(ceil(F(-NAN)));
    TEST_FLT_NAN(ceil(-F(NAN)));

    TEST_FLT(ceilf(F(3.9)), 4.0);
    TEST_FLT(ceilf(F(-3.3)), -3.0);
    TEST_FLT(ceilf(F(-3.9)), -3.0);
    TEST_FLT(ceilf(F(INFINITY)), INFINITY);
    TEST_FLT(ceilf(F(-INFINITY)), -INFINITY);
    TEST_FLT_NAN(ceilf(F(NAN)));
    TEST_FLT_NAN(ceilf(F(-NAN)));
    TEST_FLT_NAN(ceilf(-F(NAN)));

    TEST_FLT(ceill(F(3.9)), 4.0);
    TEST_FLT(ceill(F(-3.3)), -3.0);
    TEST_FLT(ceill(F(-3.9)), -3.0);
    TEST_FLT(ceill(F(INFINITY)), INFINITY);
    TEST_FLT(ceill(F(-INFINITY)), -INFINITY);
    TEST_FLT_NAN(ceill(F(NAN)));
    TEST_FLT_NAN(ceill(F(-NAN)));
    TEST_FLT_NAN(ceill(-F(NAN)));

    TEST_FLT(trunc(F(3.9)), 3.0);
    TEST_FLT(trunc(F(-3.3)), -3.0);
    TEST_FLT(trunc(F(-3.9)), -3.0);
    TEST_FLT(trunc(F(INFINITY)), INFINITY);
    TEST_FLT(trunc(F(-INFINITY)), -INFINITY);
    TEST_FLT_NAN(trunc(F(NAN)));
    TEST_FLT_NAN(trunc(F(-NAN)));
    TEST_FLT_NAN(trunc(-F(NAN)));

    TEST_FLT(truncf(F(3.9)), 3.0);
    TEST_FLT(truncf(F(-3.3)), -3.0);
    TEST_FLT(truncf(F(-3.9)), -3.0);
    TEST_FLT(truncf(F(INFINITY)), INFINITY);
    TEST_FLT(truncf(F(-INFINITY)), -INFINITY);
    TEST_FLT_NAN(truncf(F(NAN)));
    TEST_FLT_NAN(truncf(F(-NAN)));
    TEST_FLT_NAN(truncf(-F(NAN)));

    TEST_FLT(truncl(F(3.9)), 3.0);
    TEST_FLT(truncl(F(-3.3)), -3.0);
    TEST_FLT(truncl(F(-3.9)), -3.0);
    TEST_FLT(truncl(F(INFINITY)), INFINITY);
    TEST_FLT(truncl(F(-INFINITY)), -INFINITY);
    TEST_FLT_NAN(truncl(F(NAN)));
    TEST_FLT_NAN(truncl(F(-NAN)));
    TEST_FLT_NAN(truncl(-F(NAN)));

    TEST_FLT(sqrt(F(9)), 3.0);
    TEST_FLT(sqrt(F(0.25)), 0.5);
    TEST_FLT(sqrtf(F(9)), 3.0);
    TEST_FLT(sqrtf(F(0.25)), 0.5);
    TEST_FLT(sqrtl(F(9)), 3.0);
    TEST_FLT(sqrtl(F(0.25)), 0.5);

    TEST_FLT(fma(F(2), F(3), F(4)), 10);
    TEST_FLT_NAN(fma(F(NAN), F(3), F(4)));
    TEST_FLT_NAN(fma(F(2), F(NAN), F(4)));
    TEST_FLT_NAN(fma(F(2), F(3), F(NAN)));
    TEST_FLT(fmaf(F(2), F(3), F(4)), 10);
    TEST_FLT_NAN(fmaf(F(NAN), F(3), F(4)));
    TEST_FLT_NAN(fmaf(F(2), F(NAN), F(4)));
    TEST_FLT_NAN(fmaf(F(2), F(3), F(NAN)));
    TEST_FLT(fmal(F(2), F(3), F(4)), 10);
    TEST_FLT_NAN(fmal(F(NAN), F(3), F(4)));
    TEST_FLT_NAN(fmal(F(2), F(NAN), F(4)));
    TEST_FLT_NAN(fmal(F(2), F(3), F(NAN)));

    for (i = 0; i < 2; i++) {
        if (i == 0) {
            // Use the default env in the first round here
            context = "FE_DFL_ENV ";
        } else {
            fesetround(FE_TONEAREST); // Only set it on the second round
            context = "FE_TONEAREST ";
        }

        TEST_INT(llrint(F(3.3)), 3);
        TEST_INT(llrint(F(3.6)), 4);
        TEST_INT(llrint(F(3.5)), 4);
#if !defined(__MINGW32__) || (!defined(__arm__) && !defined(__aarch64__))
        // TODO: FE_TONEAREST rounds towards nearest even number, so 4.5 rounds to 4 - mingw doesn't implement this properly yet on arm and aarch64
        TEST_INT(llrint(F(4.5)), 4);
#endif
        TEST_INT(llrint(F(-3.3)), -3);
        TEST_INT(llrint(F(-3.6)), -4);
        TEST_INT(llrint(F(-3.5)), -4);

        TEST_INT(llrintf(F(3.3)), 3);
        TEST_INT(llrintf(F(3.6)), 4);
        TEST_INT(llrintf(F(3.5)), 4);
        TEST_INT(llrintf(F(-3.3)), -3);
        TEST_INT(llrintf(F(-3.6)), -4);
        TEST_INT(llrintf(F(-3.5)), -4);

        TEST_INT(llrintl(F(3.3)), 3);
        TEST_INT(llrintl(F(3.6)), 4);
        TEST_INT(llrintl(F(3.5)), 4);
        TEST_INT(llrintl(F(-3.3)), -3);
        TEST_INT(llrintl(F(-3.6)), -4);
        TEST_INT(llrintl(F(-3.5)), -4);

        TEST_INT(lrint(F(3.3)), 3);
        TEST_INT(lrint(F(3.6)), 4);
        TEST_INT(lrint(F(3.5)), 4);
        TEST_INT(lrint(F(-3.3)), -3);
        TEST_INT(lrint(F(-3.6)), -4);
        TEST_INT(lrint(F(-3.5)), -4);

        TEST_INT(lrintf(F(3.3)), 3);
        TEST_INT(lrintf(F(3.6)), 4);
        TEST_INT(lrintf(F(3.5)), 4);
        TEST_INT(lrintf(F(-3.3)), -3);
        TEST_INT(lrintf(F(-3.6)), -4);
        TEST_INT(lrintf(F(-3.5)), -4);

        TEST_INT(lrintl(F(3.3)), 3);
        TEST_INT(lrintl(F(3.6)), 4);
        TEST_INT(lrintl(F(3.5)), 4);
        TEST_INT(lrintl(F(-3.3)), -3);
        TEST_INT(lrintl(F(-3.6)), -4);
        TEST_INT(lrintl(F(-3.5)), -4);

        TEST_FLT(rint(F(3.3)), 3.0);
        TEST_FLT(rint(F(3.6)), 4.0);
        TEST_FLT(rint(F(3.5)), 4.0);
        TEST_FLT_NAN(rint(F(NAN)));
        TEST_FLT(rint(F(-3.3)), -3.0);
        TEST_FLT(rint(F(-3.6)), -4.0);
        TEST_FLT(rint(F(-3.5)), -4.0);
        TEST_FLT_NAN(rint(F(-NAN)));

        TEST_FLT(rintf(F(3.3)), 3.0);
        TEST_FLT(rintf(F(3.6)), 4.0);
        TEST_FLT(rintf(F(3.5)), 4.0);
        TEST_FLT_NAN(rintf(F(NAN)));
        TEST_FLT(rintf(F(-3.3)), -3.0);
        TEST_FLT(rintf(F(-3.6)), -4.0);
        TEST_FLT(rintf(F(-3.5)), -4.0);
        TEST_FLT_NAN(rintf(F(-NAN)));

        TEST_FLT(rintl(F(3.3)), 3.0);
        TEST_FLT(rintl(F(3.6)), 4.0);
        TEST_FLT(rintl(F(3.5)), 4.0);
        TEST_FLT_NAN(rintl(F(NAN)));
        TEST_FLT(rintl(F(-3.3)), -3.0);
        TEST_FLT(rintl(F(-3.6)), -4.0);
        TEST_FLT(rintl(F(-3.5)), -4.0);
        TEST_FLT_NAN(rintl(F(-NAN)));

        TEST_FLT(nearbyint(F(3.3)), 3.0);
        TEST_FLT(nearbyint(F(3.6)), 4.0);
        TEST_FLT(nearbyint(F(3.5)), 4.0);
        TEST_FLT_NAN(nearbyint(F(NAN)));
        TEST_FLT(nearbyint(F(-3.3)), -3.0);
        TEST_FLT(nearbyint(F(-3.6)), -4.0);
        TEST_FLT(nearbyint(F(-3.5)), -4.0);
        TEST_FLT_NAN(nearbyint(F(-NAN)));

        TEST_FLT(nearbyintf(F(3.3)), 3.0);
        TEST_FLT(nearbyintf(F(3.6)), 4.0);
        TEST_FLT(nearbyintf(F(3.5)), 4.0);
        TEST_FLT_NAN(nearbyintf(F(NAN)));
        TEST_FLT(nearbyintf(F(-3.3)), -3.0);
        TEST_FLT(nearbyintf(F(-3.6)), -4.0);
        TEST_FLT(nearbyintf(F(-3.5)), -4.0);
        TEST_FLT_NAN(nearbyintf(F(-NAN)));

        TEST_FLT(nearbyintl(F(3.3)), 3.0);
        TEST_FLT(nearbyintl(F(3.6)), 4.0);
        TEST_FLT(nearbyintl(F(3.5)), 4.0);
        TEST_FLT_NAN(nearbyintl(F(NAN)));
        TEST_FLT(nearbyintl(F(-3.3)), -3.0);
        TEST_FLT(nearbyintl(F(-3.6)), -4.0);
        TEST_FLT(nearbyintl(F(-3.5)), -4.0);
        TEST_FLT_NAN(nearbyintl(F(-NAN)));
    }

    fesetround(FE_TOWARDZERO);
    context = "FE_TOWARDZERO ";
    TEST_INT(llrint(F(3.3)), 3);
    TEST_INT(llrint(F(3.6)), 3);
    TEST_INT(llrint(F(-3.3)), -3);
    TEST_INT(llrint(F(-3.6)), -3);

    TEST_INT(llrintf(F(3.3)), 3);
    TEST_INT(llrintf(F(3.6)), 3);
    TEST_INT(llrintf(F(-3.3)), -3);
    TEST_INT(llrintf(F(-3.6)), -3);

    TEST_INT(llrintl(F(3.3)), 3);
    TEST_INT(llrintl(F(3.6)), 3);
    TEST_INT(llrintl(F(-3.3)), -3);
    TEST_INT(llrintl(F(-3.6)), -3);

    TEST_INT(lrint(F(3.3)), 3);
    TEST_INT(lrint(F(3.6)), 3);
    TEST_INT(lrint(F(-3.3)), -3);
    TEST_INT(lrint(F(-3.6)), -3);

    TEST_INT(lrintf(F(3.3)), 3);
    TEST_INT(lrintf(F(3.6)), 3);
    TEST_INT(lrintf(F(-3.3)), -3);
    TEST_INT(lrintf(F(-3.6)), -3);

    TEST_INT(lrintl(F(3.3)), 3);
    TEST_INT(lrintl(F(3.6)), 3);
    TEST_INT(lrintl(F(-3.3)), -3);
    TEST_INT(lrintl(F(-3.6)), -3);

    TEST_FLT(rint(F(3.3)), 3.0);
    TEST_FLT(rint(F(3.6)), 3.0);
    TEST_FLT(rint(F(-3.3)), -3.0);
    TEST_FLT(rint(F(-3.6)), -3.0);

    TEST_FLT(rintf(F(3.3)), 3.0);
    TEST_FLT(rintf(F(3.6)), 3.0);
    TEST_FLT(rintf(F(-3.3)), -3.0);
    TEST_FLT(rintf(F(-3.6)), -3.0);

    TEST_FLT(rintl(F(3.3)), 3.0);
    TEST_FLT(rintl(F(3.6)), 3.0);
    TEST_FLT(rintl(F(-3.3)), -3.0);
    TEST_FLT(rintl(F(-3.6)), -3.0);

    TEST_FLT(nearbyint(F(3.3)), 3.0);
    TEST_FLT(nearbyint(F(3.6)), 3.0);
    TEST_FLT(nearbyint(F(-3.3)), -3.0);
    TEST_FLT(nearbyint(F(-3.6)), -3.0);

    TEST_FLT(nearbyintf(F(3.3)), 3.0);
    TEST_FLT(nearbyintf(F(3.6)), 3.0);
    TEST_FLT(nearbyintf(F(-3.3)), -3.0);
    TEST_FLT(nearbyintf(F(-3.6)), -3.0);

    TEST_FLT(nearbyintl(F(3.3)), 3.0);
    TEST_FLT(nearbyintl(F(3.6)), 3.0);
    TEST_FLT(nearbyintl(F(-3.3)), -3.0);
    TEST_FLT(nearbyintl(F(-3.6)), -3.0);

    fesetround(FE_DOWNWARD);
    context = "FE_DOWNWARD ";
    TEST_INT(llrint(F(3.3)), 3);
    TEST_INT(llrint(F(3.6)), 3);
    TEST_INT(llrint(F(-3.3)), -4);
    TEST_INT(llrint(F(-3.6)), -4);

    TEST_INT(llrintf(F(3.3)), 3);
    TEST_INT(llrintf(F(3.6)), 3);
    TEST_INT(llrintf(F(-3.3)), -4);
    TEST_INT(llrintf(F(-3.6)), -4);

    TEST_INT(llrintl(F(3.3)), 3);
    TEST_INT(llrintl(F(3.6)), 3);
    TEST_INT(llrintl(F(-3.3)), -4);
    TEST_INT(llrintl(F(-3.6)), -4);

    TEST_INT(lrint(F(3.3)), 3);
    TEST_INT(lrint(F(3.6)), 3);
    TEST_INT(lrint(F(-3.3)), -4);
    TEST_INT(lrint(F(-3.6)), -4);

    TEST_INT(lrintf(F(3.3)), 3);
    TEST_INT(lrintf(F(3.6)), 3);
    TEST_INT(lrintf(F(-3.3)), -4);
    TEST_INT(lrintf(F(-3.6)), -4);

    TEST_INT(lrintl(F(3.3)), 3);
    TEST_INT(lrintl(F(3.6)), 3);
    TEST_INT(lrintl(F(-3.3)), -4);
    TEST_INT(lrintl(F(-3.6)), -4);

    TEST_FLT(rint(F(3.3)), 3.0);
    TEST_FLT(rint(F(3.6)), 3.0);
    TEST_FLT(rint(F(-3.3)), -4.0);
    TEST_FLT(rint(F(-3.6)), -4.0);

    TEST_FLT(rintf(F(3.3)), 3.0);
    TEST_FLT(rintf(F(3.6)), 3.0);
    TEST_FLT(rintf(F(-3.3)), -4.0);
    TEST_FLT(rintf(F(-3.6)), -4.0);

    TEST_FLT(rintl(F(3.3)), 3.0);
    TEST_FLT(rintl(F(3.6)), 3.0);
    TEST_FLT(rintl(F(-3.3)), -4.0);
    TEST_FLT(rintl(F(-3.6)), -4.0);

    TEST_FLT(nearbyint(F(3.3)), 3.0);
    TEST_FLT(nearbyint(F(3.6)), 3.0);
    TEST_FLT(nearbyint(F(-3.3)), -4.0);
    TEST_FLT(nearbyint(F(-3.6)), -4.0);

    TEST_FLT(nearbyintf(F(3.3)), 3.0);
    TEST_FLT(nearbyintf(F(3.6)), 3.0);
    TEST_FLT(nearbyintf(F(-3.3)), -4.0);
    TEST_FLT(nearbyintf(F(-3.6)), -4.0);

    TEST_FLT(nearbyintl(F(3.3)), 3.0);
    TEST_FLT(nearbyintl(F(3.6)), 3.0);
    TEST_FLT(nearbyintl(F(-3.3)), -4.0);
    TEST_FLT(nearbyintl(F(-3.6)), -4.0);

    fesetround(FE_UPWARD);
    context = "FE_UPWARD ";
    TEST_INT(llrint(F(3.3)), 4);
    TEST_INT(llrint(F(3.6)), 4);
    TEST_INT(llrint(F(-3.3)), -3);
    TEST_INT(llrint(F(-3.6)), -3);

    TEST_INT(llrintf(F(3.3)), 4);
    TEST_INT(llrintf(F(3.6)), 4);
    TEST_INT(llrintf(F(-3.3)), -3);
    TEST_INT(llrintf(F(-3.6)), -3);

    TEST_INT(llrintl(F(3.3)), 4);
    TEST_INT(llrintl(F(3.6)), 4);
    TEST_INT(llrintl(F(-3.3)), -3);
    TEST_INT(llrintl(F(-3.6)), -3);

    TEST_INT(lrint(F(3.3)), 4);
    TEST_INT(lrint(F(3.6)), 4);
    TEST_INT(lrint(F(-3.3)), -3);
    TEST_INT(lrint(F(-3.6)), -3);

    TEST_INT(lrintf(F(3.3)), 4);
    TEST_INT(lrintf(F(3.6)), 4);
    TEST_INT(lrintf(F(-3.3)), -3);
    TEST_INT(lrintf(F(-3.6)), -3);

    TEST_INT(lrintl(F(3.3)), 4);
    TEST_INT(lrintl(F(3.6)), 4);
    TEST_INT(lrintl(F(-3.3)), -3);
    TEST_INT(lrintl(F(-3.6)), -3);

    TEST_FLT(rint(F(3.3)), 4.0);
    TEST_FLT(rint(F(3.6)), 4.0);
    TEST_FLT(rint(F(-3.3)), -3.0);
    TEST_FLT(rint(F(-3.6)), -3.0);

    TEST_FLT(rintf(F(3.3)), 4.0);
    TEST_FLT(rintf(F(3.6)), 4.0);
    TEST_FLT(rintf(F(-3.3)), -3.0);
    TEST_FLT(rintf(F(-3.6)), -3.0);

    TEST_FLT(rintl(F(3.3)), 4.0);
    TEST_FLT(rintl(F(3.6)), 4.0);
    TEST_FLT(rintl(F(-3.3)), -3.0);
    TEST_FLT(rintl(F(-3.6)), -3.0);

    TEST_FLT(nearbyint(F(3.3)), 4.0);
    TEST_FLT(nearbyint(F(3.6)), 4.0);
    TEST_FLT(nearbyint(F(-3.3)), -3.0);
    TEST_FLT(nearbyint(F(-3.6)), -3.0);

    TEST_FLT(nearbyintf(F(3.3)), 4.0);
    TEST_FLT(nearbyintf(F(3.6)), 4.0);
    TEST_FLT(nearbyintf(F(-3.3)), -3.0);
    TEST_FLT(nearbyintf(F(-3.6)), -3.0);

    TEST_FLT(nearbyintl(F(3.3)), 4.0);
    TEST_FLT(nearbyintl(F(3.6)), 4.0);
    TEST_FLT(nearbyintl(F(-3.3)), -3.0);
    TEST_FLT(nearbyintl(F(-3.6)), -3.0);

    context = "";

    TEST_FLT_ACCURACY(log2(F(1.0)), 0.0, 0.001);
    TEST_FLT_ACCURACY(log2(F(8.0)), 3.0, 0.001);
    TEST_FLT_ACCURACY(log2(F(1024.0)), 10.0, 0.001);
    TEST_FLT_ACCURACY(log2(F(1048576.0)), 20.0, 0.001);
    TEST_FLT_ACCURACY(log2(F(4294967296.0)), 32.0, 0.001);
    TEST_FLT_ACCURACY(log2(F(9.7656e-04)), -10, 0.001);
    TEST_FLT_ACCURACY(log2(F(9.5367e-07)), -20, 0.001);
    TEST_FLT_ACCURACY(log2(F(3.5527e-15)), -48, 0.001);
    TEST_FLT_ACCURACY(log2(F(7.8886e-31)), -100, 0.001);
    TEST_FLT_ACCURACY(log2(F(7.3468e-40)), -130, 0.001);
#if !defined(__MINGW32__) || !defined(__arm__)
    // on mingw-arm, this gives -inf
    TEST_FLT_ACCURACY(log2(F(9.8813e-324)), -1073, 0.001);
#endif
    TEST_FLT_ACCURACY(log2(F(1.225000)), 0.292782, 0.001);

    TEST_FLT_ACCURACY(log2f(F(1.0)), 0.0, 0.001);
    TEST_FLT_ACCURACY(log2f(F(8.0)), 3.0, 0.001);
    TEST_FLT_ACCURACY(log2f(F(1024.0)), 10.0, 0.001);
    TEST_FLT_ACCURACY(log2f(F(1048576.0)), 20.0, 0.001);
    TEST_FLT_ACCURACY(log2f(F(4294967296.0)), 32.0, 0.001);
    TEST_FLT_ACCURACY(log2f(F(9.7656e-04)), -10, 0.001);
    TEST_FLT_ACCURACY(log2f(F(9.5367e-07)), -20, 0.001);
    TEST_FLT_ACCURACY(log2f(F(3.5527e-15)), -48, 0.001);
    TEST_FLT_ACCURACY(log2f(F(7.8886e-31)), -100, 0.001);
    TEST_FLT_ACCURACY(log2f(F(7.3468e-40)), -130, 0.001);
    TEST_FLT_ACCURACY(log2f(F(7.1746e-43)), -140, 0.001);
    TEST_FLT_ACCURACY(log2f(F(1.225000)), 0.292782, 0.001); // This crashes the mingw-w64 softfloat implementation

    TEST_INT(llround(F(3.3)), 3);
    TEST_INT(llround(F(3.6)), 4);
    TEST_INT(llround(F(3.5)), 4);
    TEST_INT(llround(F(4.5)), 5);
    TEST_INT(llround(F(-3.3)), -3);
    TEST_INT(llround(F(-3.6)), -4);
    TEST_INT(llround(F(-3.5)), -4);
    TEST_INT(llround(F(-4.5)), -5);

    TEST_INT(llroundf(F(3.3)), 3);
    TEST_INT(llroundf(F(3.6)), 4);
    TEST_INT(llroundf(F(3.5)), 4);
    TEST_INT(llroundf(F(4.5)), 5);
    TEST_INT(llroundf(F(-3.3)), -3);
    TEST_INT(llroundf(F(-3.6)), -4);
    TEST_INT(llroundf(F(-3.5)), -4);
    TEST_INT(llroundf(F(-4.5)), -5);

    TEST_INT(llroundl(F(3.3)), 3);
    TEST_INT(llroundl(F(3.6)), 4);
    TEST_INT(llroundl(F(3.5)), 4);
    TEST_INT(llroundl(F(4.5)), 5);
    TEST_INT(llroundl(F(-3.3)), -3);
    TEST_INT(llroundl(F(-3.6)), -4);
    TEST_INT(llroundl(F(-3.5)), -4);
    TEST_INT(llroundl(F(-4.5)), -5);

    TEST_INT(lround(F(3.3)), 3);
    TEST_INT(lround(F(3.6)), 4);
    TEST_INT(lround(F(3.5)), 4);
    TEST_INT(lround(F(4.5)), 5);
    TEST_INT(lround(F(-3.3)), -3);
    TEST_INT(lround(F(-3.6)), -4);
    TEST_INT(lround(F(-3.5)), -4);
    TEST_INT(lround(F(-4.5)), -5);

    TEST_INT(lroundf(F(3.3)), 3);
    TEST_INT(lroundf(F(3.6)), 4);
    TEST_INT(lroundf(F(3.5)), 4);
    TEST_INT(lroundf(F(4.5)), 5);
    TEST_INT(lroundf(F(-3.3)), -3);
    TEST_INT(lroundf(F(-3.6)), -4);
    TEST_INT(lroundf(F(-3.5)), -4);
    TEST_INT(lroundf(F(-4.5)), -5);

    TEST_INT(lroundl(F(3.3)), 3);
    TEST_INT(lroundl(F(3.6)), 4);
    TEST_INT(lroundl(F(3.5)), 4);
    TEST_INT(lroundl(F(4.5)), 5);
    TEST_INT(lroundl(F(-3.3)), -3);
    TEST_INT(lroundl(F(-3.6)), -4);
    TEST_INT(lroundl(F(-3.5)), -4);
    TEST_INT(lroundl(F(-4.5)), -5);

    TEST_FLT(round(F(3.3)), 3.0);
    TEST_FLT(round(F(3.6)), 4.0);
    TEST_FLT(round(F(3.5)), 4.0);
    TEST_FLT(round(F(4.5)), 5.0);
    TEST_FLT_NAN(round(F(NAN)));
    TEST_FLT(round(F(-3.3)), -3.0);
    TEST_FLT(round(F(-3.6)), -4.0);
    TEST_FLT(round(F(-3.5)), -4.0);
    TEST_FLT(round(F(-4.5)), -5.0);
    TEST_FLT_NAN(round(F(-NAN)));

    TEST_FLT(roundf(F(3.3)), 3.0);
    TEST_FLT(roundf(F(3.6)), 4.0);
    TEST_FLT(roundf(F(3.5)), 4.0);
    TEST_FLT(roundf(F(4.5)), 5.0);
    TEST_FLT_NAN(roundf(F(NAN)));
    TEST_FLT(roundf(F(-3.3)), -3.0);
    TEST_FLT(roundf(F(-3.6)), -4.0);
    TEST_FLT(roundf(F(-3.5)), -4.0);
    TEST_FLT(roundf(F(-4.5)), -5.0);
    TEST_FLT_NAN(roundf(F(-NAN)));

    TEST_FLT(roundl(F(3.3)), 3.0);
    TEST_FLT(roundl(F(3.6)), 4.0);
    TEST_FLT(roundl(F(3.5)), 4.0);
    TEST_FLT(roundl(F(4.5)), 5.0);
    TEST_FLT_NAN(roundl(F(NAN)));
    TEST_FLT(roundl(F(-3.3)), -3.0);
    TEST_FLT(roundl(F(-3.6)), -4.0);
    TEST_FLT(roundl(F(-3.5)), -4.0);
    TEST_FLT(roundl(F(-4.5)), -5.0);
    TEST_FLT_NAN(roundl(F(-NAN)));

    TEST_FLT(pow(F(2.0), F(0.0)), 1.0);
    TEST_FLT(powf(F(2.0), F(0.0)), 1.0);
    TEST_FLT(pow(F(10.0), F(0.0)), 1.0);
    TEST_FLT(pow(F(10.0), F(1.0)), 10.0);
    TEST_FLT_ACCURACY(pow(F(10.0), F(0.5)), 3.162278, 0.01);
#if !defined(__MINGW32__) || (!defined(__arm__) && !defined(__aarch64__))
    // TODO: Missing on mingw on arm and aarch64
    TEST_FLT(powl(F(2.0), F(0.0)), 1.0);
#endif

    TEST_FLT_ACCURACY(cos(F(0.0)), 1.0, 0.01);
    TEST_FLT_ACCURACY(sin(F(0.0)), 0.0, 0.01);

#ifdef _WIN32
    TEST_FLT_ACCURACY(_copysign(F(3.125), F(1)), 3.125, 0.0001);
    TEST_FLT_ACCURACY(_copysign(F(3.125), F(-1)), -3.125, 0.0001);
    TEST_FLT_ACCURACY(_copysign(F(-3.125), F(-1)), -3.125, 0.0001);
    TEST_FLT_ACCURACY(_copysign(F(-3.125), F(1)), 3.125, 0.0001);
    TEST_FLT_NAN(_copysign(F(NAN), F(-1)));
    TEST_FLT(_copysign(F(INFINITY), F(1)), INFINITY);
    TEST_FLT(_copysign(F(INFINITY), F(-1)), -INFINITY);
    TEST_FLT(_copysign(F(-INFINITY), F(-1)), -INFINITY);
    TEST_FLT(_copysign(F(-INFINITY), F(1)), INFINITY);
#if !defined(__MINGW32__) || (!defined(__i386__) || __MSVCRT_VERSION__ >= 0x1400)
    // The _copysignf function is missing in msvcrt.dll on i386
    TEST_FLT_ACCURACY(_copysignf(F(3.125), F(1)), 3.125, 0.0001);
    TEST_FLT_ACCURACY(_copysignf(F(3.125), F(-1)), -3.125, 0.0001);
    TEST_FLT_ACCURACY(_copysignf(F(-3.125), F(-1)), -3.125, 0.0001);
    TEST_FLT_ACCURACY(_copysignf(F(-3.125), F(1)), 3.125, 0.0001);
    TEST_FLT(_copysignf(F(INFINITY), F(1)), INFINITY);
    TEST_FLT(_copysignf(F(INFINITY), F(-1)), -INFINITY);
    TEST_FLT(_copysignf(F(-INFINITY), F(-1)), -INFINITY);
    TEST_FLT(_copysignf(F(-INFINITY), F(1)), INFINITY);
    TEST_FLT_NAN(_copysignf(F(NAN), F(-1)));
#endif
    TEST_FLT_ACCURACY(_copysignl(F(3.125), F(1)), 3.125, 0.0001);
    TEST_FLT_ACCURACY(_copysignl(F(-3.125), F(-1)), -3.125, 0.0001);
    TEST_FLT_ACCURACY(_copysignl(F(3.125), F(-1)), -3.125, 0.0001);
    TEST_FLT_ACCURACY(_copysignl(F(-3.125), F(1)), 3.125, 0.0001);
#if !defined(__MINGW32__) || !defined(__x86_64__)
    // These tests give incorrect results on x86_64 mingw
    TEST_FLT(_copysignl(F(INFINITY), F(1)), INFINITY);
    TEST_FLT(_copysignl(F(INFINITY), F(-1)), -INFINITY);
    TEST_FLT(_copysignl(F(-INFINITY), F(-1)), -INFINITY);
    TEST_FLT(_copysignl(F(-INFINITY), F(1)), INFINITY);
    TEST_FLT_NAN(_copysignl(F(NAN), F(-1)));
#endif
    TEST_FLT_ACCURACY(copysign(F(3.125), F(1)), 3.125, 0.0001);
    TEST_FLT_ACCURACY(copysign(F(3.125), F(-1)), -3.125, 0.0001);
    TEST_FLT_ACCURACY(copysign(F(-3.125), F(-1)), -3.125, 0.0001);
    TEST_FLT_ACCURACY(copysign(F(-3.125), F(1)), 3.125, 0.0001);
    TEST_FLT(copysign(F(INFINITY), F(1)), INFINITY);
    TEST_FLT(copysign(F(INFINITY), F(-1)), -INFINITY);
    TEST_FLT(copysign(F(-INFINITY), F(-1)), -INFINITY);
    TEST_FLT(copysign(F(-INFINITY), F(1)), INFINITY);
    TEST_FLT_NAN(copysign(F(NAN), F(-1)));
    TEST_FLT_ACCURACY(copysignf(F(3.125), F(1)), 3.125, 0.0001);
    TEST_FLT_ACCURACY(copysignf(F(3.125), F(-1)), -3.125, 0.0001);
    TEST_FLT_ACCURACY(copysignf(F(-3.125), F(-1)), -3.125, 0.0001);
    TEST_FLT_ACCURACY(copysignf(F(-3.125), F(1)), 3.125, 0.0001);
    TEST_FLT(copysignf(F(INFINITY), F(1)), INFINITY);
    TEST_FLT(copysignf(F(INFINITY), F(-1)), -INFINITY);
    TEST_FLT(copysignf(F(-INFINITY), F(-1)), -INFINITY);
    TEST_FLT(copysignf(F(-INFINITY), F(1)), INFINITY);
    TEST_FLT_NAN(copysignf(F(NAN), F(-1)));
    TEST_FLT_ACCURACY(copysignl(F(3.125), F(1)), 3.125, 0.0001);
    TEST_FLT_ACCURACY(copysignl(F(-3.125), F(-1)), -3.125, 0.0001);
    TEST_FLT_ACCURACY(copysignl(F(3.125), F(-1)), -3.125, 0.0001);
    TEST_FLT_ACCURACY(copysignl(F(-3.125), F(1)), 3.125, 0.0001);
#if !defined(__MINGW32__) || !defined(__x86_64__)
    // These tests give incorrect results on x86_64 mingw
    TEST_FLT(copysignl(F(INFINITY), F(1)), INFINITY);
    TEST_FLT(copysignl(F(INFINITY), F(-1)), -INFINITY);
    TEST_FLT(copysignl(F(-INFINITY), F(-1)), -INFINITY);
    TEST_FLT(copysignl(F(-INFINITY), F(1)), INFINITY);
    TEST_FLT_NAN(copysignl(F(NAN), F(-1)));
#endif

    TEST_FLT_ACCURACY(_chgsignl(F(3.125)), -3.125, 0.0001);
    TEST_FLT_ACCURACY(_chgsignl(F(-3.125)), 3.125, 0.0001);
    TEST_FLT(_chgsignl(F(INFINITY)), -INFINITY);
    TEST_FLT(_chgsignl(F(-INFINITY)), INFINITY);
    TEST_FLT_NAN(_chgsignl(F(NAN)));
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
    InterlockedBitTestAndSet(&value, 0);
    TEST_INT(value, 1);
    __int64 ret;
    ret = InterlockedBitTestAndSet(&value, 2);
    TEST_INT(ret, 0);
    TEST_INT(value, 5);
    ret = InterlockedBitTestAndSet(&value, 2);
    TEST_INT(ret, 1);
    TEST_INT(value, 5);
    __int64 value64 = 0;
#if !defined(__MINGW32__) || !defined(__arm__)
    ret = InterlockedIncrement64(&value64);
    TEST_INT(ret, 1);
    TEST_INT(value64, 1);
    ret = InterlockedIncrement64(&value64);
    TEST_INT(ret, 2);
#else
    // InterlockedIncrement64 is missing on mingw on arm
    value64 = 2;
#endif
    TEST_INT(value64, 2);
#if !defined(__MINGW32__) || defined(_WIN64)
    ret = InterlockedAdd64(&value64, 3);
    TEST_INT(ret, 5);
    TEST_INT(value64, 5);
#else
    // InterlockedAdd64 is missing on mingw on i386 and arm
    value64 += 3;
#endif
#if !defined(__MINGW32__) || !defined(__arm__)
    // Or returns the previous value
    ret = InterlockedOr64(&value64, 2);
    TEST_INT(ret, 5);
    TEST_INT(value64, 7);
    ret = InterlockedOr64(&value64, 2);
    TEST_INT(ret, 7);
    TEST_INT(value64, 7);
#endif
#endif

    printf("%d tests, %d failures\n", tests, fails);
    return fails > 0;
}
