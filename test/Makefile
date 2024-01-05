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
    CROSS = $(ARCH)-linux-musl-
endif
CC = $(CROSS)gcc$(TOOLEXT)
CXX = $(CROSS)g++$(TOOLEXT)

ifneq ($(COPY),)
    COPY_TARGET = $(COPY) $@
    COPY_DEP = $(COPY) $<
else
    COPY_TARGET = @:
    COPY_DEP = @:
endif
ifneq ($(QEMU),)
    DO_RUN = LD_LIBRARY_PATH=. $(QEMU) -L $(SYSROOT) # Trailing whitespace
    DO_RUN_STATIC = $(DO_RUN)
else
    DO_RUN = LD_LIBRARY_PATH=.:$(SYSROOT)/usr/lib $(INTERPRETER) # Trailing whitespace
    DO_RUN_STATIC = ./
endif

EXEEXT =
DLLEXT = .so
DLLPREFIX = lib

# Available everywhere by default, but can be skipped by passing HAVE_OPENMP=
#HAVE_OPENMP =

# hello-tls
TESTS_C = hello crt-test setjmp
TESTS_C_NO_BUILTIN = crt-test
# tlstest-main
TESTS_CPP = hello-cpp global-terminate longjmp-cleanup
TESTS_CPP_EXCEPTIONS = hello-exception exception-locale exception-reduced
TESTS_CPP_STATIC = hello-exception
# tlstest-lib
TESTS_CPP_DLL = throwcatch-lib
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
TESTS_ATOMIC = atomic-helpers

TARGETS_C = $(addsuffix $(EXEEXT), $(TESTS_C))
TARGETS_C_NO_BUILTIN = $(addsuffix -no-builtin$(EXEEXT), $(TESTS_C_NO_BUILTIN))
TARGETS_CPP = $(addsuffix $(EXEEXT), $(TESTS_CPP))
TARGETS_CPP_EXCEPTIONS = $(addsuffix $(EXEEXT), $(TESTS_CPP_EXCEPTIONS))
TARGETS_CPP_EXCEPTIONS_OPT = $(addsuffix -opt$(EXEEXT), $(TESTS_CPP_EXCEPTIONS))
TARGETS_CPP_STATIC = $(addsuffix -static$(EXEEXT), $(TESTS_CPP_STATIC))
TARGETS_CPP_DLL = $(addprefix $(DLLPREFIX), $(addsuffix $(DLLEXT), $(TESTS_CPP_DLL)))
TARGETS_CPP_LINK_DLL = $(addsuffix $(EXEEXT), $(TESTS_CPP_LINK_DLL))
TARGETS_SSP = $(addsuffix $(EXEEXT), $(TESTS_SSP))
TARGETS_FORTIFY = $(addsuffix -fortify$(EXEEXT), $(TESTS_FORTIFY))
TARGETS_ASAN = $(addsuffix -asan$(EXEEXT), $(TESTS_ASAN))
TARGETS_UBSAN = $(addsuffix $(EXEEXT), $(TESTS_UBSAN))
TARGETS_OMP = $(addsuffix $(EXEEXT), $(TESTS_OMP))
TARGETS_ATOMIC = $(addsuffix $(EXEEXT), $(TESTS_ATOMIC))

TARGETS = \
    $(TARGETS_C) $(TARGETS_C_NO_BUILTIN) \
    $(TARGETS_CPP) $(TARGETS_CPP_EXCEPTIONS) $(TARGETS_CPP_EXCEPTIONS_OPT) $(TARGETS_CPP_STATIC) $(TARGETS_CPP_DLL) $(TARGETS_CPP_LINK_DLL) \
    $(TARGETS_SSP) $(TARGETS_FORTIFY) \
    $(TARGETS_OTHER_TARGETS) $(TARGETS_UWP) $(TARGETS_UWP_FAIL) \
    $(TARGETS_ASAN) $(TARGETS_UBSAN) \
    $(TARGETS_OMP) $(TARGETS_ATOMIC)

# musl doesn't have fortify, so the bufferoverflow tests don't
# trigger any failures with fortify.
FAILURE_TESTS = \
    $(TARGETS_SSP) \
    $(TARGETS_ASAN) $(TARGETS_UBSAN)

EXTRAFILES =

all: $(TARGETS)

# A custom dependency outside of the generic patterns
tlstest-main$(EXEEXT): tlstest-lib$(DLLEXT)

$(TARGETS_C): %$(EXEEXT): %.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $< -o $@

$(TARGETS_C_DLL): $(DLLPREFIX)%$(DLLEXT): %.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $< -shared -o $@ -fPIC
	$(COPY_TARGET)

$(TARGETS_CPP_DLL): $(DLLPREFIX)%$(DLLEXT): %.cpp
	$(CXX) $(CPPFLAGS) $(CFLAGS) $< -shared -o $@ -fPIC
	$(COPY_TARGET)

$(TARGETS_C_NO_BUILTIN): %-no-builtin$(EXEEXT): %.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $< -o $@ -fno-builtin

$(TARGETS_CPP_EXCEPTIONS_OPT): %-opt$(EXEEXT): %.cpp
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) $< -o $@ -O2

$(TARGETS_CPP) $(TARGETS_CPP_EXCEPTIONS): %$(EXEEXT): %.cpp
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) $< -o $@

$(TARGETS_CPP_STATIC): %-static$(EXEEXT): %.cpp
	$(CXX) -static $< -o $@

$(TARGETS_SSP): %$(EXEEXT): %.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $< -o $@ -fstack-protector-strong

$(TARGETS_FORTIFY): %-fortify$(EXEEXT): %.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $< -o $@ -O2 -D_FORTIFY_SOURCE=2

$(TARGETS_ASAN): %-asan$(EXEEXT): %.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $< -o $@ -fsanitize=address -g

$(TARGETS_UBSAN): %$(EXEEXT): %.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $< -o $@ -fsanitize=undefined -fno-sanitize-recover=all

$(TARGETS_OMP): %$(EXEEXT): %.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $< -o $@ -fopenmp=libomp

$(TARGETS_ATOMIC): %$(EXEEXT): %.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $< -o $@ -Wno-atomic-alignment

.SECONDEXPANSION:
$(TARGETS_C_LINK_DLL): %$(EXEEXT): %.c $(DLLPREFIX)$$(subst -main,-lib,$$*)$(DLLEXT)
	$(CC) $< -o $@ -L. -l$(subst -main,-lib,$*)

$(TARGETS_CPP_LINK_DLL): %$(EXEEXT): %.cpp $(DLLPREFIX)$$(subst -main,-lib,$$*)$(DLLEXT)
	$(CXX) $< -o $@ -L. -l$(subst -main,-lib,$*)

TESTS = $(filter-out %$(DLLEXT), $(TARGETS))
ifeq ($(NATIVE),)
    # The x86_64 crt-test fails in qemu
    TESTS := $(filter-out crt-test%, $(TESTS))
endif
TEST_TARGETS = $(addprefix .tested., $(TESTS))
TEST_TARGETS_STATIC = $(addprefix .tested., $(TARGETS_CPP_STATIC))

FAILURE_TEST_TARGETS = $(addprefix .failtested., $(FAILURE_TESTS))
#CUSTOM1_FAILURE_TEST_TARGETS = .customtest1.bufferoverflow-fortify$(EXEEXT)

ALL_TEST_TARGETS = $(TEST_TARGETS) $(FAILURE_TEST_TARGETS) $(CUSTOM1_FAILURE_TEST_TARGETS)

test: all $(ALL_TEST_TARGETS)

$(TEST_TARGETS_STATIC): .tested.%$(EXEEXT): %$(EXEEXT) $(LOCAL_RUNTIMES)
	$(DO_RUN_STATIC)$<
	$(TOUCH_TARGET)

$(filter-out $(TEST_TARGETS_STATIC), $(TEST_TARGETS)): .tested.%$(EXEEXT): %$(EXEEXT) $(LOCAL_RUNTIMES)
	$(DO_RUN)$<
	$(TOUCH_TARGET)

$(FAILURE_TEST_TARGETS): .failtested.%$(EXEEXT): %$(EXEEXT) $(LOCAL_RUNTIMES)
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
		stacksmash-asan) \
			grep -q stack-buffer-overflow $$OUT || { echo ERROR: $< missing mention of stack-buffer-overflow; exit 1; }; \
			grep -q "func.*stacksmash.c" $$OUT || { echo ERROR: $< missing source location; exit 1; }; \
			;; \
		ubsan) \
			grep -q "signed integer overflow" $$OUT || { echo ERROR: $< missing mention of signed integer overflow; exit 1; }; \
			;; \
		stacksmash) \
			;; \
		bufferoverflow-*) \
			grep -q "buffer overflow detected" $$OUT || { echo ERROR: $< missing mention of buffer overflow detected; exit 1; }; \
			;; \
		*) \
			echo Unhandled failure test $*; \
			exit 1; \
			;; \
		esac; \
		rm -f $$OUT; \
	fi
	@touch $@

.customtest1.%$(EXEEXT): %$(EXEEXT) $(LOCAL_RUNTIMES)
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
			grep -q "buffer overflow detected" $$OUT || { echo ERROR: $< missing mention of buffer overflow detected; exit 1; }; \
			rm -f $$OUT; \
		fi; \
		i=$$(($$i+1)); \
	done
	@touch $@

clean:
	$(RM_F) $(TARGETS) $(EXTRAFILES) $(ALL_TEST_TARGETS) $(LOCAL_RUNTIMES)

.PHONY: all test clean
