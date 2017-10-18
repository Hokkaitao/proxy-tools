#include "my_io.h"
#include <iostream>
using namespace std;
class slowlog_combine {
private:
	IO_CACHE *rf;
	IO_CACHE *wf;
	int is_mark;
	int need_flush;
public:
	int init(char *read_name, char *write_name, int size = 1024);
	~slowlog_combine() {
		if(rf) delete rf;
		if(wf) delete wf;
	}
	slowlog_combine() {
		rf = new IO_CACHE();
		wf = new IO_CACHE();
	}
	int work(); 
}; 

int slowlog_combine::init(char *read_name, char *write_name, int size) {
	assert(rf != NULL);
	assert(wf != NULL);
	rf->init_io_cache(read_name, READ_CACHE, size);
	wf->init_io_cache(write_name, WRITE_CACHE, size);
	is_mark = 1;
	need_flush = 0;
	return SUCCESS;
}
int slowlog_combine::work() {
	while(!rf->is_end()) {
		rf->read_next_line();
		rf->remove_lf();
		if(rf->is_find_char_first('#') == 0) {
			if(this->is_mark == 0) this->need_flush = 1;
			this->is_mark = 1;
		} else {
			this->is_mark = 0;
		}
		if(this->need_flush) {
			wf->add_lf();
			wf->write_next_line();
			wf->fsync();
			this->need_flush = 0;
		}
		wf->append_buffer_with_interval(rf->get_buffer(), rf->get_buffer_size());
		rf->clear_buffer();
	}
	wf->add_lf();
	wf->write_next_line();
	wf->fsync();
	return SUCCESS;
} 

