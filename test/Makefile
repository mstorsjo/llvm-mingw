#
# Copyright (c) 2022 Martin Storsjo
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

SRC_PATH=$(word 1, $(dir $(MAKEFILE_LIST)))
vpath %.c $(SRC_PATH)
vpath %.cpp $(SRC_PATH)
vpath %.idl $(SRC_PATH)
vpath %.rc $(SRC_PATH)

ifneq ($(filter %-mingw32, $(MAKE_HOST)),)
    # If we're running as mingw32-make, we're executing everything in
    # cmd.exe, so adapt/filter out things that require a POSIX shell.
    CMD = 1
    NATIVE = 1
    TOUCH_TARGET =
    RM_F = del
else
    TOUCH_TARGET = @touch $@
    RM_F = rm -f
endif

# Run with TOOLEXT=.exe to run testing with Windows tools, from Linux make
# in WSL.

ifneq ($(ARCH),)
    CROSS = $(ARCH)-w64-mingw32-
    CROSS_UWP = $(ARCH)-w64-mingw32uwp-
endif
CC = $(CROSS)gcc$(TOOLEXT)
CXX = $(CROSS)g++$(TOOLEXT)
WIDL = $(CROSS)widl$(TOOLEXT)
WINDRES = $(CROSS)windres$(TOOLEXT)
CC_UWP = $(CROSS_UWP)clang$(TOOLEXT)

ifneq ($(COPY),)
    COPY_TARGET = $(COPY) $@
    COPY_DEP = $(COPY) $<
else
    COPY_TARGET = @:
    COPY_DEP = @:
endif
ifneq ($(RUN),)
    DO_RUN = $(RUN) # trailing whitespace
else
    DO_RUN = ./
endif

EXEEXT = .exe
DLLEXT = .dll

# Available everywhere by default, but can be skipped by passing HAVE_OPENMP=
HAVE_OPENMP = 1

TESTS_C = hello hello-tls crt-test setjmp
TESTS_C_DLL = autoimport-lib
TESTS_C_LINK_DLL = autoimport-main
TESTS_C_NO_BUILTIN = crt-test
TESTS_C_ANSI_STDIO = crt-test
TESTS_CPP = hello-cpp global-terminate tlstest-main longjmp-cleanup
TESTS_CPP_EXCEPTIONS = hello-exception exception-locale exception-reduced
TESTS_CPP_STATIC = hello-exception
TESTS_CPP_DLL = tlstest-lib throwcatch-lib
TESTS_CPP_LINK_DLL = throwcatch-main
TESTS_SSP = stacksmash
TESTS_FORTIFY = bufferoverflow crt-test
ifneq ($(HAVE_SANITIZERS),)
    TESTS_ASAN = stacksmash
    TESTS_UBSAN = ubsan
endif
ifneq ($(HAVE_OPENMP),)
    TESTS_OMP = hello-omp
endif
TESTS_UWP = uwp-error
TESTS_IDL = idltest
TESTS_RES = hello-res
ifneq ($(HAVE_UWP),)
    TESTS_OTHER_TARGETS = hello
endif
ifneq ($(HAVE_CFGUARD),)
    TESTS_CFGUARD = cfguard-test
    TESTS_ASAN_CFGUARD = $(TESTS_ASAN)
endif

TARGETS_C = $(addsuffix $(EXEEXT), $(TESTS_C))
TARGETS_C_DLL = $(addsuffix $(DLLEXT), $(TESTS_C_DLL))
TARGETS_C_LINK_DLL = $(addsuffix $(EXEEXT), $(TESTS_C_LINK_DLL))
TARGETS_C_NO_BUILTIN = $(addsuffix -no-builtin$(EXEEXT), $(TESTS_C_NO_BUILTIN))
TARGETS_C_ANSI_STDIO = $(addsuffix -ansi-stdio$(EXEEXT), $(TESTS_C_ANSI_STDIO))
TARGETS_CPP = $(addsuffix $(EXEEXT), $(TESTS_CPP))
TARGETS_CPP_EXCEPTIONS = $(addsuffix $(EXEEXT), $(TESTS_CPP_EXCEPTIONS))
TARGETS_CPP_EXCEPTIONS_OPT = $(addsuffix -opt$(EXEEXT), $(TESTS_CPP_EXCEPTIONS))
TARGETS_CPP_STATIC = $(addsuffix -static$(EXEEXT), $(TESTS_CPP_STATIC))
TARGETS_CPP_DLL = $(addsuffix $(DLLEXT), $(TESTS_CPP_DLL))
TARGETS_CPP_LINK_DLL = $(addsuffix $(EXEEXT), $(TESTS_CPP_LINK_DLL))
TARGETS_SSP = $(addsuffix $(EXEEXT), $(TESTS_SSP))
TARGETS_CFGUARD = $(addsuffix $(EXEEXT), $(TESTS_CFGUARD))
TARGETS_FORTIFY = $(addsuffix -fortify$(EXEEXT), $(TESTS_FORTIFY))
TARGETS_IDL = $(addsuffix $(EXEEXT), $(TESTS_IDL))
TARGETS_RES = $(addsuffix $(EXEEXT), $(TESTS_RES))
TARGETS_OTHER_TARGETS = $(addsuffix -mingw32uwp$(EXEEXT), $(TESTS_OTHER_TARGETS))
TARGETS_UWP = $(addsuffix -mingw32$(EXEEXT), $(TESTS_UWP))
ifneq ($(HAVE_UWP),)
ifeq ($(CMD),)
    TARGETS_UWP_FAIL = $(addprefix .tested.build., $(addsuffix -mingw32uwp$(EXEEXT), $(TESTS_UWP)))
endif
endif
TARGETS_ASAN = $(addsuffix -asan$(EXEEXT), $(TESTS_ASAN))
TARGETS_UBSAN = $(addsuffix $(EXEEXT), $(TESTS_UBSAN))
TARGETS_ASAN_CFGUARD = $(addsuffix -asan-cfguard$(EXEEXT), $(TESTS_ASAN_CFGUARD))
TARGETS_OMP = $(addsuffix $(EXEEXT), $(TESTS_OMP))

TARGETS = \
    $(TARGETS_C) $(TARGETS_C_DLL) $(TARGETS_C_LINK_DLL) $(TARGETS_C_NO_BUILTIN) $(TARGETS_C_ANSI_STDIO) \
    $(TARGETS_CPP) $(TARGETS_CPP_EXCEPTIONS) $(TARGETS_CPP_EXCEPTIONS_OPT) $(TARGETS_CPP_STATIC) $(TARGETS_CPP_DLL) $(TARGETS_CPP_LINK_DLL) \
    $(TARGETS_SSP) $(TARGETS_CFGUARD) $(TARGETS_FORTIFY) \
    $(TARGETS_IDL) $(TARGETS_RES) \
    $(TARGETS_OTHER_TARGETS) $(TARGETS_UWP) $(TARGETS_UWP_FAIL) \
    $(TARGETS_ASAN) $(TARGETS_UBSAN) $(TARGETS_ASAN_CFGUARD) \
    $(TARGETS_OMP)

# crt-test-fortify doesn't trigger failures
FAILURE_TESTS = \
    $(TARGETS_SSP) \
    $(filter-out crt-test-fortify$(EXEEXT), $(TARGETS_FORTIFY)) \
    $(TARGETS_ASAN) $(TARGETS_UBSAN) $(TARGETS_ASAN_CFGUARD)

EXTRAFILES = \
     $(addprefix lib, $(addsuffix .dll.a, $(TESTS_C_DLL))) \
     $(addprefix lib, $(addsuffix .dll.a, $(TESTS_CPP_DLL))) \
     $(addsuffix .h, $(TESTS_IDL)) \
     $(addsuffix -rc.o, $(TESTS_RES)) \
     $(addsuffix -asan.pdb, $(TESTS_ASAN)) \
     $(addsuffix -asan-cfguard.pdb, $(TESTS_ASAN_CFGUARD))

all: $(TARGETS)

# A custom dependency outside of the generic patterns
tlstest-main$(EXEEXT): tlstest-lib$(DLLEXT)

$(TARGETS_C): %$(EXEEXT): %.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $< -o $@

$(TARGETS_C_DLL): %$(DLLEXT): %.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $< -shared -o $@ -Wl,--out-implib,lib$*.dll.a
	$(COPY_TARGET)

$(TARGETS_CPP_DLL): %$(DLLEXT): %.cpp
	$(CXX) $(CPPFLAGS) $(CFLAGS) $< -shared -o $@ -Wl,--out-implib,lib$*.dll.a
	$(COPY_TARGET)

$(TARGETS_C_NO_BUILTIN): %-no-builtin$(EXEEXT): %.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $< -o $@ -fno-builtin

$(TARGETS_C_ANSI_STDIO): %-ansi-stdio$(EXEEXT): %.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $< -o $@ -D__USE_MINGW_ANSI_STDIO=1

$(TARGETS_CPP_EXCEPTIONS_OPT): %-opt$(EXEEXT): %.cpp
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) $< -o $@ -O2

$(TARGETS_CPP) $(TARGETS_CPP_EXCEPTIONS): %$(EXEEXT): %.cpp
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) $< -o $@

$(TARGETS_CPP_STATIC): %-static$(EXEEXT): %.cpp
	$(CXX) -static $< -o $@

$(TARGETS_SSP): %$(EXEEXT): %.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $< -o $@ -fstack-protector-strong

$(TARGETS_CFGUARD): %$(EXEEXT): %.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $< -o $@ -mguard=cf

$(TARGETS_FORTIFY): %-fortify$(EXEEXT): %.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $< -o $@ -O2 -D_FORTIFY_SOURCE=2

$(TARGETS_ASAN): %-asan$(EXEEXT): %.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $< -o $@ -fsanitize=address -g -gcodeview -Wl,--pdb=

$(TARGETS_UBSAN): %$(EXEEXT): %.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $< -o $@ -fsanitize=undefined -fno-sanitize-recover=all

# Smoke test ASAN with CFGuard to make sure it doesn't trip.
$(TARGETS_ASAN_CFGUARD): %-asan-cfguard$(EXEEXT): %.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $< -o $@ -fsanitize=address -g -gcodeview -mguard=cf -Wl,--pdb=

$(TARGETS_OMP): %$(EXEEXT): %.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $< -o $@ -fopenmp=libomp

%.h: %.idl
	$(WIDL) $< -h -o $@

$(TARGETS_IDL): %$(EXEEXT): %.c %.h
	$(CC) $(CPPFLAGS) $(CFLAGS) $< -o $@ -I. -lole32

%.o: %.rc
	$(WINDRES) $< $@

$(TARGETS_RES): %$(EXEEXT): %.c %-rc.o
	$(CC) $(CPPFLAGS) $(CFLAGS) $+ -o $@

$(TARGETS_OTHER_TARGETS): %-mingw32uwp$(EXEEXT): %.c
	$(CC_UWP) $< -o $@

$(TARGETS_UWP): %-mingw32$(EXEEXT): %.c
	$(CC) $< -o $@ -Wimplicit-function-declaration -Werror

$(TARGETS_UWP_FAIL): .tested.build.%-mingw32uwp$(EXEEXT): %.c
	@echo $(CC_UWP) $< -o $@ -Wimplicit-function-declaration -Werror
	@if $(CC_UWP) $< -o $@ -Wimplicit-function-declaration -Werror; then echo ERROR: $@ should have failed; rm -f $@; exit 1; else echo OK: UWP build failed intentionally; touch $@; fi

.SECONDEXPANSION:
$(TARGETS_C_LINK_DLL): %$(EXEEXT): %.c $$(subst -main,-lib,$$*)$(DLLEXT)
	$(CC) $< -o $@ -L. -l$(subst -main,-lib,$*)

$(TARGETS_CPP_LINK_DLL): %$(EXEEXT): %.cpp $$(subst -main,-lib,$$*)$(DLLEXT)
	$(CXX) $< -o $@ -L. -l$(subst -main,-lib,$*)

COMPILER_RT_ARCH = $(ARCH)
ifeq ($(ARCH), i686)
    COMPILER_RT_ARCH = i386
endif

RUNTIMES = libc++ libunwind libclang_rt.asan_dynamic-$(COMPILER_RT_ARCH) libomp
ifneq ($(RUNTIMES_SRC),)
LOCAL_RUNTIMES = $(patsubst $(RUNTIMES_SRC)/%, %, $(wildcard $(addprefix $(RUNTIMES_SRC)/, $(addsuffix $(DLLEXT), $(RUNTIMES)))))

$(LOCAL_RUNTIMES): %$(DLLEXT): $(RUNTIMES_SRC)/%$(DLLEXT)
	cp -a $< $@
	$(COPY_TARGET)

all: $(LOCAL_RUNTIMES)
endif

TESTS = $(filter-out %$(DLLEXT), $(TARGETS))
# TARGETS_UWP_FAIL isn't a real executable, but a placeholder file to indicate
# that we tested (and failed) to compile the file.
TESTS := $(filter-out $(TARGETS_UWP_FAIL), $(TESTS))
# TARGETS_IDL is a build-only test.
TESTS := $(filter-out $(TARGETS_IDL), $(TESTS))
ifeq ($(NATIVE),)
    # Only test asan on native Windows, as it doesn't run in Wine.
    TESTS := $(filter-out $(TARGETS_ASAN) $(TARGETS_ASAN_CFGUARD), $(TESTS))
    FAILURE_TESTS := $(filter-out $(TARGETS_ASAN) $(TARGETS_ASAN_CFGUARD), $(FAILURE_TESTS))
endif
TEST_TARGETS = $(addprefix .tested., $(TESTS))

ifneq ($(NATIVE),)
ifeq ($(CMD),)
    # These don't strictly require running native instead of in Wine
    # (except for asan, but that's are already filtered out at this
    # point), but some of the error situations trigger crashes, which
    # might not work robustly on all exotic Wine configurations - thus
    # only run these tests on native Windows.
    # These tests don't support being run in cmd.exe.
    FAILURE_TEST_TARGETS = $(addprefix .failtested., $(FAILURE_TESTS))
    CUSTOM1_FAILURE_TEST_TARGETS = .customtest1.bufferoverflow-fortify$(EXEEXT)
    ifneq ($(HAVE_CFGUARD),)
    ifeq ($(WSL),)
        # These tests do special calling of cmd.exe, which don't quite
        # work when running with Linux make in WSL.
        CUSTOM2_FAILURE_TEST_TARGETS = .customtest2.cfguard-test$(EXEEXT)
    endif
    endif
endif
endif

ALL_TEST_TARGETS = $(TEST_TARGETS) $(FAILURE_TEST_TARGETS) $(CUSTOM1_FAILURE_TEST_TARGETS) $(CUSTOM2_FAILURE_TEST_TARGETS)

COPY_TARGETS = $(patsubst .tested.%, .copied.%, $(TEST_TARGETS))

test: all $(ALL_TEST_TARGETS)

.copied.%: %
	$(COPY_DEP)
	$(TOUCH_TARGET)

$(TEST_TARGETS): .tested.%$(EXEEXT): %$(EXEEXT) .copied.%$(EXEEXT) $(LOCAL_RUNTIMES)
	$(DO_RUN)$<
	$(TOUCH_TARGET)

$(FAILURE_TEST_TARGETS): .failtested.%$(EXEEXT): %$(EXEEXT) .copied.%$(EXEEXT) $(LOCAL_RUNTIMES)
	@echo $(DO_RUN)$< trigger; \
	OUT=log1-$*; \
	if $(DO_RUN)$< trigger > $$OUT 2>&1; then \
		cat $$OUT; \
		rm -f $$OUT; \
		echo ERROR: $< trigger should have failed; \
		exit 1; \
	else \
		ret=$$?; \
		cat $$OUT; \
		echo OK: $< trigger failed expectedly, returned $$ret; \
		case $* in \
		stacksmash-asan|stacksmash-asan-cfguard) \
			grep -q stack-buffer-overflow $$OUT || exit 1; \
			grep -q "func.*stacksmash.c" $$OUT || exit 1; \
			;; \
		ubsan) \
			grep -q "signed integer overflow" $$OUT || exit 1; \
			;; \
		stacksmash) \
			grep -q "stack smashing detected" $$OUT || exit 1; \
			;; \
		bufferoverflow-*) \
			grep -q "buffer overflow detected" $$OUT || exit 1; \
			;; \
		*) \
			echo Unhandled failure test $*; \
			exit 1; \
			;; \
		esac; \
		rm -f $$OUT; \
	fi
	@touch $@

.customtest1.%$(EXEEXT): %$(EXEEXT) .copied.%$(EXEEXT) $(LOCAL_RUNTIMES)
	@i=0; while [ $$i -le 10 ]; do \
		OUT=log2-$*; \
		rm -f $$OUT; \
		echo $(DO_RUN)$< $$i; \
		if $(DO_RUN)$< $$i > $$OUT 2>&1; then \
			cat $$OUT; \
			echo ERROR: $* $$i should have failed; \
			rm -f $$OUT; \
			exit 1; \
		else \
			ret=$$?; \
			cat $$OUT; \
			echo OK: $* $$i failed expectedly, returned $$ret; \
			grep -q "buffer overflow detected" $$OUT || exit 1; \
			rm -f $$OUT; \
		fi; \
		i=$$(($$i+1)); \
	done
	@touch $@

# We want to check the exit code to be 0xc0000409 (STATUS_STACK_BUFFER_OVERRUN
# aka fail fast exception). MSYS2 bash does not give us the full 32-bit exit
# code, so we have to rely on cmd.exe to perform the check. (This probably
# doesn't work on Wine, but Wine doesn't support CFG anyway, at least not for
# now...)
.customtest2.%$(EXEEXT): %$(EXEEXT) .copied.%$(EXEEXT) $(LOCAL_RUNTIMES)
	@echo $(DO_RUN)$< check_enabled
	@if $(DO_RUN)$< check_enabled; then \
		echo $(DO_RUN)$< normal_icall; \
		$(DO_RUN)$< normal_icall || exit 1; \
		echo $(DO_RUN)$< invalid_icall_nocf; \
		$(DO_RUN)$< invalid_icall_nocf; \
		[ $$? = 2 ] || exit 1; \
		echo $(DO_RUN)$< invalid_icall; \
		cmd.exe //v:on //c "$< invalid_icall & if !errorlevel! equ -1073740791 (exit 0) else (exit 1)"; \
		[ $$? = 0 ] || exit 1; \
	fi
	@touch $@

clean:
	$(RM_F) $(TARGETS) $(EXTRAFILES) $(ALL_TEST_TARGETS) $(COPY_TARGETS) $(LOCAL_RUNTIMES)

.PHONY: all test clean
