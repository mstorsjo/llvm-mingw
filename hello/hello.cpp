#include <iostream>

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

int main(int argc, char* argv[]) {
	std::cout<<"Hello world C++"<<std::endl;
	return 0;
}
