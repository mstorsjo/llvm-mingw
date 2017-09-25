#include <iostream>
#include <stdio.h>

class Hello {
public:
	Hello() {
		printf("Hello ctor\n");
	}
	~Hello() {
		printf("Hello dtor\n");
	}
};

Hello global_h;

class RecurseClass {
public:
	RecurseClass(int v) : val(v) {
		printf("ctor %d\n", val);
	}
	~RecurseClass() {
		printf("dtor %d\n", val);
	}
private:
	int val;
};

void recurse(int val) {
	RecurseClass obj(val);
	if (val == 0) {
		throw std::exception();
	}
	if (val == 5) {
		try {
			recurse(val - 1);
		} catch (std::exception& e) {
			printf("caught exception at %d\n", val);
		}
	} else {
		recurse(val - 1);
	}
	printf("finishing function recurse %d\n", val);
}

int main(int argc, char* argv[]) {
	std::cout<<"Hello world C++"<<std::endl;
	recurse(10);
	return 0;
}
