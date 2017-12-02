#include <windows.h>
#include <stdio.h>
#include <process.h>

#if defined(_MSC_VER)
static __declspec(thread) int tlsvar = 1;
#else
static __thread int tlsvar = 1;
#endif

static unsigned __stdcall threadfunc(void* arg) {
	int id = (int)arg;
	printf("thread %d, tlsvar %p %d\n", id, &tlsvar, tlsvar);
	tlsvar = id + 100;
	for (int i = 0; i < 5; i++) {
		printf("thread %d, tlsvar %p %d\n", id, &tlsvar, tlsvar);
		tlsvar += 10;
		Sleep(1000);
	}
	return 0;
}

int main(int argc, char* argv[]) {
	HANDLE threads[5];

	for (int i = 0; i < 5; i++) {
		printf("mainthread, tlsvar %p %d\n", &tlsvar, tlsvar);
		tlsvar += 10;
		threads[i] = (HANDLE)_beginthreadex(NULL, 0, threadfunc, (void*)(intptr_t) (i + 1), 0, NULL);
		Sleep(750);
	}
	for (int i = 0; i < 5; i++) {
		WaitForSingleObject(threads[i], INFINITE);
		CloseHandle(threads[i]);
	}
	return 0;
}
