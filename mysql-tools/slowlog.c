#include <cstdlib>
#include <iostream>
#include "my_io.h"
#include "slowlog_combine.h"
using namespace std;

int main(int argc, char **argv) {
	if(argc < 3) {
		cout<<"please assign input file & output file"<<endl;
	}
	slowlog_combine *sc = new slowlog_combine();
	sc->init(argv[1], argv[2], 5200);
	sc->work();

	return 0;
}
