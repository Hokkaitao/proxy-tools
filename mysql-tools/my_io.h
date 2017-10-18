#ifndef __IO_CACHE__
#define __IO_CACHE__
#include <stdio.h>
#include <assert.h>

/**
 * combine file and buffer togeter
 * _______________________________________
 * |XXXXXXXXX////////////0_______________| 
 * |         |             |             |
 * buff      last_pos      next_pos      end_pos
 * 0                                     max_size - 1
 */

#define _max(A, B) (A>B?A:B)

#define IO_CACHE_BUFFER_MAX_SIZE 1024

enum IO_CACHE_ERR {
	NOT_FIND = -1,
	SUCCESS = 0,
	INVALID_PARAMETER = 1, 
	INVALID_OPERATE,
	FILE_OPERATE_ERROR, 
	OVERFLOW_ERROR,
	FAILD
};

enum cache_type {
	TYPE_NOT_SET = 0,
	READ_CACHE,
	WRITE_CACHE, 
	TYPE_NUM
};

class IO_CACHE {
private:
	FILE *fd;
	enum cache_type type;
	char *buffer;

	int end_pos;
	int next_pos;
	int last_pos;
public:
	IO_CACHE():fd(NULL),type(TYPE_NOT_SET), buffer(NULL), end_pos(0), next_pos(0) {} 
	~IO_CACHE() {
		if(fd) fclose(fd);
		if(buffer) free(buffer);
	}

	int init_io_cache(FILE *fd, enum cache_type type, int size=1024);
	int init_io_cache(char *name, enum cache_type type, int size=1024);

	int read_next_line();
	int read_next_line_remove_lf();
	int write_next_line(int pos = 0);
	int write_next_line_add_lf(int pos = 0);
	int write_last_line();
	int append_buffer(char *buf, int len);
	int append_buffer_add_lf(char *buf, int len);
	int append_buffer_with_interval(char *buf, int len, char *interval = " ");
	void fsync();

	char* get_buffer(int pos=0);
	int get_buffer_size();
	int get_buffer_max_size();
	int get_next_pos();
	int get_end_pos();
	int get_free_size();
	int get_used_size();
	int clear_buffer();

	int  remove_lf();
	int add_lf();

	int is_end();
	int is_find_char_first(char p);
};

int IO_CACHE::init_io_cache(FILE *fd, enum cache_type type, int size) {
	if(fd == NULL) return INVALID_PARAMETER;
	if(type <= TYPE_NOT_SET ||type >= TYPE_NUM) return INVALID_PARAMETER;	
	if(size <= 0) return INVALID_PARAMETER;
	
	this->fd = fd;
	this->type = type;

	this->buffer = (char*)malloc(sizeof(char) * size);
	if(this->buffer == NULL) {
		return FAILD;
	}
	memset(this->buffer, 0, size);

	this->end_pos = size;
	this->next_pos = 0;
	this->last_pos = 0;

	return SUCCESS;
}

int IO_CACHE::init_io_cache(char *name, enum cache_type type, int size) {
	if(name == NULL) return INVALID_PARAMETER;
	if(type <= TYPE_NOT_SET ||type >= TYPE_NUM) return INVALID_PARAMETER;
	if(size <=0 ) return INVALID_PARAMETER;

	this->type = type;
	switch(this->type) {
		case READ_CACHE:{
			this->fd = fopen(name, "r");			
			break;
		}
		case WRITE_CACHE: {
			this->fd = fopen(name, "w");			
			break;
		}
		default: {
			return INVALID_PARAMETER;
		}
	}	

	this->buffer = (char*)malloc(sizeof(char) * size);
	if(this->buffer == NULL) {
		return FAILD;
	}
	memset(this->buffer, 0, size);

	this->end_pos = size - 1;
	this->next_pos = 0;
	this->last_pos = 0;
		
	return SUCCESS;
}

int IO_CACHE::read_next_line() {
	assert(this->fd != NULL);
	if(type != READ_CACHE) return INVALID_OPERATE;
	int to_read = _max(IO_CACHE_BUFFER_MAX_SIZE, this->end_pos+1);	
	if(fgets((this->buffer + this->next_pos), to_read, this->fd) == NULL) {
		return FILE_OPERATE_ERROR;
	}
	this->last_pos = this->next_pos;
	this->next_pos+=strlen(this->buffer + this->next_pos);
	return SUCCESS;
}

int IO_CACHE::write_next_line(int pos) {
	assert(this->fd != NULL);
	if(pos > this->end_pos) return INVALID_PARAMETER;
	if(type != WRITE_CACHE) return INVALID_OPERATE;
	if(!fputs(this->buffer + pos, this->fd)) {
		return FILE_OPERATE_ERROR;
	} 
	memset(this->buffer+pos, 0, this->end_pos+1);
	this->next_pos = 0;
	this->last_pos = 0;
	return SUCCESS;
}
int IO_CACHE::write_last_line() {
	char *to_write = (char *)malloc(sizeof(char) * this->last_pos);	
	memset(to_write, 0, this->last_pos);
	memcpy(to_write, this->buffer, this->last_pos);
	if(!fputs(to_write, this->fd)) {
		return FILE_OPERATE_ERROR;
	}
	memset(this->buffer, 0, this->last_pos);
	memcpy(this->buffer, this->buffer + this->last_pos, this->next_pos - this->last_pos);
	memset(this->buffer + this->last_pos, 0, this->next_pos - this->last_pos);
	this->next_pos -= this->last_pos;
	this->last_pos = 0;
}

void IO_CACHE::fsync() {
	assert(this->fd != NULL);
	fflush(this->fd);
}

char* IO_CACHE:: get_buffer(int pos) {
	return this->buffer + pos;
}
int IO_CACHE::get_buffer_size() {
	return this->next_pos;
}
int IO_CACHE::get_buffer_max_size() {
	return this->end_pos + 1;	
}
int IO_CACHE::get_next_pos() {
	return this->next_pos;
}
int IO_CACHE::get_end_pos() {
	return this->end_pos;
}

int IO_CACHE::remove_lf() {
	if(*(this->buffer + this->next_pos - 1) == '\n') *(this->buffer + --this->next_pos) = '\0';	
	return SUCCESS;
}

int IO_CACHE::add_lf() {
	if(this->next_pos > this->end_pos) return OVERFLOW_ERROR;
	*(this->buffer + this->next_pos++) = '\n';
}

int IO_CACHE::get_free_size() {
	return (this->end_pos + 1 - this->next_pos);
}
int IO_CACHE::get_used_size() {
	return (this->next_pos);
}
int IO_CACHE::append_buffer(char *buf, int len) {
	if(buf == NULL) return INVALID_PARAMETER;
	if(this->next_pos + len -1 > this->end_pos) return OVERFLOW_ERROR;
	memcpy(this->buffer + this->next_pos, buf, len);
	this->last_pos = this->next_pos;
	this->next_pos += len;
	return SUCCESS;
}
int IO_CACHE::append_buffer_with_interval(char *buf, int len, char *interval) {
	int ret = SUCCESS;
	ret |= append_buffer(interval, strlen(interval));	
	ret |= append_buffer(buf, len);
	return ret;
}
int IO_CACHE::append_buffer_add_lf(char *buf, int len) {
	int ret = SUCCESS;
	ret |= this->append_buffer(buf, len);
	ret |= this->add_lf();
	return ret;	
}
int IO_CACHE::read_next_line_remove_lf() {
	int ret = SUCCESS;
	ret |= this->read_next_line();
	ret |= this->remove_lf();
	return ret;

}
int IO_CACHE::write_next_line_add_lf(int pos) {
	int ret = SUCCESS;
	ret |= this->add_lf();
	ret |= this->write_next_line();
	return ret;	
}
int IO_CACHE::clear_buffer() {
	memset(this->buffer, 0, this->end_pos + 1);
	this->next_pos = 0;
	this->last_pos = 0;
	return SUCCESS;
}
int IO_CACHE::is_end() {
	return feof(this->fd);
}
int IO_CACHE::is_find_char_first(char p) {
	if(this->buffer == NULL) return NOT_FIND;
	char *cur = this->buffer;
	while(cur - this->buffer < this->next_pos) {
		if(*cur == p) return (cur - this->buffer);
		cur++;
	}
	return NOT_FIND;
}
#endif

