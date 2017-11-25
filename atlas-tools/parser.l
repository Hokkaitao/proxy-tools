%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <glib.h>

#define SQL_YEAR 1
#define SQL_TIME 2
#define SQL_YEARB 3
#define SQL_TIMEB 4
#define SQL_CLIENT 5
#define SQL_DBC 6
#define SQL_USERC 7
#define SQL_SERVER 8
#define SQL_ID 9
#define SQL_DBS 10
#define SQL_USERS 11
#define SQL_TYPE 12
#define SQL_BYTES 13
#define SQL_ROWS 14
#define SQL_LATENCY 15
#define SQL_STATE 16
#define SQL_SQL 17
#define SQL_END 18
#define SQL_SLOW 19
#define SQL_OTHER 20
#define SQL_LF 21
#define SQL_IGNORE 22
#define SQL_BEGIN 23
#define SQL_ANNOTATION 24

#define SQL_KEYWORD 101
#define SQL_IDENTIFIER 102
#define SQL_LEFTBRACKET 103
#define SQL_RIGHTBRACKET 104
#define SQL_TEXTSTRING 105
#define SQL_COMMA 106
#define SQL_OPERATOR 107
#define SQL_SEMICOLON 108
#define SQL_VALUE 109
#define SQL_INVALID 110

#define SQL_KEY_START_TRANS 201
#define SQL_KEY_END_TRANS 202
#define SQL_KEY_AUTOCOMMIT 203

#define SQL_TYPE_INSERT 0x1
#define SQL_TYPE_UPDATE 0x2
#define SQL_TYPE_DELETE 0x4
#define SQL_TYPE_SELECT 0x8
#define SQL_TYPE_OTHER 0x10

#define check_insert(x) (x & 0x1)
#define check_update(x) (x & 0x2)
#define check_delete(x) (x & 0x4)
#define check_select(x) (x & 0x8)
#define check_other(x) (x & 0x10)

int sql_type_state[4] = {0};

#define MAX_STRING_LEN 128
#define MAX_SQL_KEY_LEN 1024
%}

%s STATE_SQL
%s STATE_META

linefeed [\n]
digit [0-9]
letter [A-Za-z]
id [A-Za-z_][A-Z0a-z0-9_]*
colon [:]
lineblank [ ]
%%
<INITIAL>^{digit}{4}-{digit}{2}-{digit}{2} {BEGIN STATE_META;return SQL_BEGIN;}
<STATE_META>^{digit}{4}-{digit}{2}-{digit}{2} {BEGIN STATE_META;return SQL_YEAR;}
<STATE_META>{digit}{2}:{digit}{2}:{digit}{2}.{digit}+/{colon} {return SQL_TIME;}
<STATE_META>"C_begin:"{digit}{4}-{digit}{2}-{digit}{2} {return SQL_YEARB;}
<STATE_META>{digit}{2}:{digit}{2}:{digit}{2}.{digit}+/" C" {return SQL_TIMEB;}
<STATE_META>"C:"{digit}{1,3}.{digit}{1,3}.{digit}{1,3}.{digit}{1,3}:{digit}+ {return SQL_CLIENT;}
<STATE_META>"C_db:"{id} {return SQL_DBC;}
<STATE_META>"C_usr:"[^ ]* {return SQL_USERC;}
<STATE_META>"S:"{digit}{1,3}.{digit}{1,3}.{digit}{1,3}.{digit}{1,3}:{digit}+ {return SQL_SERVER;}
<STATE_META>"thread_id:"{digit}+/")" {return SQL_ID;}
<STATE_META>"S_db:"{id} {return SQL_DBS;}
<STATE_META>"S_usr:"[^ ]* {return SQL_USERS;}
<STATE_META>"type:"{digit}+ {return SQL_TYPE;}
<STATE_META>"bytes:"{digit}+ {return SQL_BYTES;}
<STATE_META>"rows:"{digit}+ {return SQL_ROWS;}
<STATE_META>{digit}+(.{digit}+)?/"(ms)" {return SQL_LATENCY;}
<STATE_META>{letter}+/" Query:" {return SQL_STATE;}
<STATE_META>"Query:" {BEGIN STATE_SQL; return SQL_SQL;}
<STATE_META>"[Slow Query]" {return SQL_SLOW;}
<STATE_META>. {return SQL_OTHER;}
<STATE_SQL>"/*"[^*]*[*]+([^*/][^*]*[*]+)*[*]*"/" {return SQL_ANNOTATION;}
<STATE_SQL>start|begin {return SQL_KEY_START_TRANS;}
<STATE_SQL>commit|rollback {return SQL_KEY_END_TRANS;}
<STATE_SQL>autocommit {return SQL_KEY_AUTOCOMMIT;}
<STATE_SQL>add|all|alter|and|any|as|asc|avg|by|char(acter)?|column|create|cascade|constraint|date|distinct|double|default|default|delete|desc|drop|exists|foreign|float|from|group|having|in|index|insert|into|is|int(eger)?|join|key|left|like|max|min|not|null|or|order|outer|primary|real|references|right|schema|select|set|smallint|sum|table|union|unique|update|value(s)?|varchar|where {return SQL_KEYWORD;}
<STATE_SQL>[A-Za-z_][A-Z0a-z0-9_]* {return SQL_IDENTIFIER;}
<STATE_SQL>[(] {return SQL_LEFTBRACKET;}
<STATE_SQL>[)] {return SQL_RIGHTBRACKET;}
<STATE_SQL>'[^']*'|\"[^\"]*\" {return SQL_TEXTSTRING;}
<STATE_SQL>[,] {return SQL_COMMA;}
<STATE_SQL>"<="|">="|"<>"|"!="|[!=]|<STATE_SQL>[*+-/.=<>] {return SQL_OPERATOR;}
<STATE_SQL>[;] {return SQL_SEMICOLON;}
<STATE_SQL>[0-9]+|[0-9]+"."[0-9]+|"."[0-9]+ {return SQL_VALUE;}
<STATE_SQL>({lineblank}*{linefeed}*)*{linefeed}/{digit}{4}-{digit}{2}-{digit}{2} {BEGIN STATE_META; return SQL_END;}
<STATE_SQL>({lineblank}*{linefeed}*)* { return SQL_LF;}
<STATE_SQL>. {return SQL_INVALID;}
%%
long long getTick(const char *time) {
    if(time == NULL) return 0;
    struct tm stm;
    int iY, iM, iD, iH, iMin, iS;
    char str_time[MAX_STRING_LEN] = {""};
    memset(&stm,0,sizeof(stm));
    memcpy(str_time, time, strlen(time));
    iY = atoi(str_time);
    iM = atoi(str_time+5);
    iD = atoi(str_time+8);
    iH = atoi(str_time+11);
    iMin = atoi(str_time+14);
    iS = atoi(str_time+17);

    stm.tm_year=iY-1900;
    stm.tm_mon=iM-1;
    stm.tm_mday=iD;
    stm.tm_hour=iH;
    stm.tm_min=iMin;
    stm.tm_sec=iS;

    return mktime(&stm);
}
long long getTick2(const char *date, const char *time) {
    if(date == NULL || time == NULL) return 0;
    struct tm stm;
    int iY, iM, iD, iH, iMin, iS;
    char str_date[MAX_STRING_LEN] = {""};
    char str_time[MAX_STRING_LEN] = {""};
    memcpy(str_date, date, strlen(date));
    memcpy(str_time, time, strlen(time));
    iY = atoi(str_date);
    iM = atoi(str_date+5);
    iD = atoi(str_date+8);
    iH = atoi(str_time);
    iMin = atoi(str_time+3);
    iS = atoi(str_time+3);

    stm.tm_year=iY-1900;
    stm.tm_mon=iM-1;
    stm.tm_mday=iD;
    stm.tm_hour=iH;
    stm.tm_min=iMin;
    stm.tm_sec=iS;

    return mktime(&stm);
}
void setDate(const char *date, struct tm *t) {
    if(date == NULL) return;
    char str_date[MAX_STRING_LEN] = {""};
    memcpy(str_date, date, strlen(date));
    t->tm_year = atoi(str_date) - 1900;
    t->tm_mon = atoi(str_date+5) - 1;
    t->tm_mday = atoi(str_date+8);
}
void setTime(const char *time, struct tm *t) {
    if(time == NULL) return;
    char str_time[MAX_STRING_LEN] = {""};
    memcpy(str_time, time, strlen(time));
    t->tm_hour = atoi(str_time);
    t->tm_min = atoi(str_time+3);
    t->tm_sec = atoi(str_time+6);
}
void formatTick(long long time, char *dst) {
    if(dst == NULL) return;
    time_t t = time;
    struct tm *lt = localtime(&t);
    strftime(dst, MAX_STRING_LEN, "%Y-%m-%d %H:%M:%S", lt);
}
int checkTime(const char *time) {
    if(time == NULL) return 0;
    int len = strlen(time);
    int loop = 0;
    int count1 = 0, count2 = 0, count3 = 0;
    for(loop = 0; loop<len; loop++) {
        if(time[loop] == '-') {
            count1++;
        }
        if(time[loop] == ':') {
            count2++;
        }
        if(time[loop] == ' ') {
            count3++;
        }
    }
    return (count1 == 2)&&(count2 == 2)&&(count3 == 1);
}
long getus(char *time) {
    if(time == NULL) return 0;
    int len = strlen(time);
    int loop = 0;
    for(loop=0; loop<len; loop++) {
        if(time[loop] == '.') {
            break;
        }
    }
    if(loop == len) {
        return 0;
    } else {
        return atol((time + loop +1));
    }
}
void year_string2int(const char *src, int *dst) {
    if(src == NULL) {
        *dst = 0;
        return;
    }
    char tmp[MAX_STRING_LEN] = {""};
    memcpy(tmp, src, strlen(src));
    char *delim = "-";
    int y, m, d;
    y = atoi(strtok(tmp, delim));
    m = atoi(strtok(NULL, delim));
    d = atoi(strtok(NULL, delim));
    *dst = y*10000+m*100+d;
}
void year_int2string(const int src, char *dst) {
    if(dst == NULL) {
        return;
    }
    char tmp[MAX_STRING_LEN] = {""};
    int y, m, d;
    y = src/10000;
    m = (src - y*10000)/100;
    d = src - y*10000 - m*100;
    if(m<10 && d<10) { 
        sprintf(tmp, "%4d-0%d-0%d", y, m, d);
    } else if(m<10 && d>=10){
        sprintf(tmp, "%4d-0%d-%2d", y, m, d);
    } else if(m>=10 && d<10) {
        sprintf(tmp, "%4d-%2d-0%d", y, m, d);
    } else {
        sprintf(tmp, "%4d-%2d-%2d", y, m, d);
    }
    memcpy(dst, tmp, strlen(tmp));
}
void time_string2int(const char *src, long long *dst) {
    if(src == NULL) {
        return;
    }
    char tmp[MAX_STRING_LEN] = {""};
    char *delim = ":", *delim_sub = ".", *p;
    memcpy(tmp, src, strlen(src));
    int h, m, s;
    long x;
    h = atoi(strtok(tmp, delim));
    m = atoi(strtok(NULL, delim));
    s = atoi(strtok(NULL, delim_sub));
    x = atoi(strtok(NULL, delim_sub));
    *dst = h*pow(10, 10)+m*pow(10, 8)+s*pow(10, 6)+x;
}
void time_int2string(const long long src, char *dst) {
    if(dst == NULL) {
        return;
    }
    char tmp[MAX_STRING_LEN] = {""};
    int h, m, s;
    long x;
    h = src/pow(10, 10);
    m = (src - h*pow(10, 10))/pow(10, 8);
    s = (src - h*pow(10, 10) - m*pow(10, 8))/pow(10, 6);
    x = (src - h*pow(10, 10) - m*pow(10, 8) - s*pow(10, 6));
    if(h<10 && m<10 && s<10) {
        sprintf(tmp, "0%d:0%d:0%d.%d", h, m, s, x);
    } else if(h<10 && m<10 && s>=10) {
        sprintf(tmp, "0%d:0%d:%2d.%d", h, m, s, x);
    } else if(h<10 && m>=10 && s<10) {
        sprintf(tmp, "0%d:%2d:0%d.%d", h, m, s, x);
    } else if(h>=10 && m<10 && s<10) {
        sprintf(tmp, "%2d:0%d:0%d.%d", h, m, s, x);
    } else if(h>=10 && m>=10 && s<10) {
        sprintf(tmp, "%2d:%2d:0%d.%d", h, m, s, x);
    } else if(h>=10 && m<10 && s>=10) {
        sprintf(tmp, "%2d:0%d:%2d.%d", h, m, s, x);
    } else if(h<10 && m>=10 && m>=10) {
        sprintf(tmp, "0%d:%2d:%2d.%d", h, m, s, x);
    } else {
        sprintf(tmp, "%2d:%2d:%2d.%d", h, m, s, x);
    }
    memcpy(dst, tmp, strlen(tmp));
}
void get_first_second(const char *src, char *dst1, char *dst2, char *delim) {
    if(src == NULL || dst1 == NULL || dst2 == NULL || delim == NULL) {
        return;
    }
    char tmp[MAX_STRING_LEN] = {""};
    memcpy(tmp, src, strlen(src));
    char *p = strtok(tmp, delim);
    if(p  == NULL) return;
    memcpy(dst1, p, strlen(p));
    char *q = strtok(NULL, delim);
    if(q == NULL) return;
    memcpy(dst2, q, strlen(q));
}
void get_second(const char *src, char *dst, char *delim) {
    if(src == NULL || dst == NULL || delim == NULL) {
        return;
    }
    char tmp[MAX_STRING_LEN] = {""};
    memcpy(tmp, src, strlen(src));
    char *p = strtok(tmp, delim);
    if(p == NULL) return;
    memcpy(dst,src + strlen(p) + 1,strlen(src) - strlen(p) - 1 );
}
void host_string2int(const char *src, int *ip, int *port) {
    if(src == NULL || ip == NULL || port == NULL) {
        return;
    }
    char s[MAX_STRING_LEN] = {""};
    memcpy(s, src, strlen(src));
    char ss[MAX_STRING_LEN] = {""};
    char *delim = ".", *delim_sub = ":";
    int p1, p2, p3, p4, p;
    p1 = atoi(strtok(s, delim));
    p2 = atoi(strtok(NULL, delim));
    p3 = atoi(strtok(NULL, delim));
    p4 = atoi(strtok(NULL, delim_sub));
    p = atoi(strtok(NULL, delim_sub));
    *ip = p1*pow(128, 3) + p2*pow(128, 2) + p3*pow(128, 1) + p4;
    *port = p;
}
void host_int2string(const int ip, const int port, char *dst) {
    if(dst == NULL) {
        return;
    }
    char tmp[MAX_STRING_LEN] = {""};
    int p1, p2, p3, p4;
    p1 = ip/pow(128, 3);
    p2 = (ip - p1*pow(128, 3))/pow(128, 2);
    p3 = (ip - p1*pow(128, 3) - p2*pow(128, 2))/pow(128, 1);
    p4 = ip - p1*pow(128, 3) - p2*pow(128, 2) - p3*pow(128, 1);
    sprintf(tmp, "%d.%d.%d.%d:%d", p1, p2, p3, p4, port);
    memcpy(dst, tmp, strlen(tmp));
}

int yywrap() {
    return 1;
}

typedef struct _log_record {
    struct tm log_time;
    long log_us;
    struct tm  sql_time;
    long sql_us;
    int client_ip;
    int client_port;
    char client_db[MAX_STRING_LEN];
    char client_user[MAX_STRING_LEN];
    int server_ip;
    int server_port;
    char server_db[MAX_STRING_LEN];
    char server_user[MAX_STRING_LEN];
    int thread_id;
    int type;
    int bytes;
    int rows;
    double latency;
    int state;
    int slow;
    int sql_type;
    GString *sql;
    GString *prototype;
    char signature[MAX_STRING_LEN];
	char annotation[MAX_STRING_LEN];

	int start_trans;
	int end_trans;
	int set_autocommit;
}LogRecord, *LOGRECORD;

void get_date(const int year, const int time, char *dst) {
    if(dst == NULL) {
        return;
    }
    char y[MAX_STRING_LEN] = {""};
    char t[MAX_STRING_LEN] = {""};
    year_int2string(year, y);
    time_int2string(time, t);
    sprintf(dst, "%s %s", y!=NULL?y:"", t!=NULL?t:"");
}
void log_format(const LogRecord logRecord, GString *dst, int flag) {
    if(dst == NULL) {
        return;
    }
    char tmp[MAX_STRING_LEN] = {""};
    formatTick(mktime(&(logRecord.log_time)), tmp);
    g_string_append_printf(dst, "%s.%ld ", tmp, logRecord.log_us);

    memset(tmp, 0, MAX_STRING_LEN);
    formatTick(mktime(&(logRecord.sql_time)), tmp);
    g_string_append_printf(dst, "C_begin:%s.%ld ", tmp, logRecord.sql_us);

    //client info
    memset(tmp, 0, MAX_STRING_LEN);
    host_int2string(logRecord.client_ip, logRecord.client_port, tmp);
    g_string_append_printf(dst, "C:%s ", tmp);

    g_string_append_printf(dst, "C_db:%s ", logRecord.client_db);
    g_string_append_printf(dst, "C_usr:%s ", logRecord.client_user);

    //server info
    memset(tmp, 0, MAX_STRING_LEN);
    host_int2string(logRecord.server_ip, logRecord.server_port, tmp);
    g_string_append_printf(dst, "S:%s(thread_id:%d) ", tmp, logRecord.thread_id);

    g_string_append_printf(dst, "S_db:%s ", logRecord.server_db);
    g_string_append_printf(dst, "S_usr:%s ", logRecord.server_user);

    //type bytes rows latency
    g_string_append_printf(dst,"inj(type:%d bytes:%d rows:%d) ", logRecord.type, logRecord.bytes, logRecord.rows);
    g_string_append_printf(dst, "%lf(ms) ", logRecord.latency);

    //OK
    g_string_append_printf(dst, "%s Query:", logRecord.state == 1?"OK":"ERR");

    //sql
    g_string_append_printf(dst, "%s%s", logRecord.annotation, logRecord.sql != NULL?logRecord.sql->str:"");
    if(flag & 0x1) {
        //prototype signature
        g_string_append_printf(dst, "prototype:%s ", logRecord.prototype != NULL?logRecord.prototype->str:"");
    }
    if(flag & 0x2) {
        g_string_append_printf(dst, "signature:%s", logRecord.signature);
    }
}
void log_format_p(const LOGRECORD logRecord, GString *dst, int flag) {
    if(dst == NULL ||logRecord == NULL) {
        return;
    }
    char tmp[MAX_STRING_LEN] = {""};
    formatTick(mktime(&(logRecord->log_time)), tmp);
    g_string_append_printf(dst, "%s.%ld ", tmp, logRecord->log_us);

    memset(tmp, 0, MAX_STRING_LEN);
    formatTick(mktime(&(logRecord->sql_time)), tmp);
    g_string_append_printf(dst, "C_begin:%s.%ld ", tmp, logRecord->sql_us);

    //client info
    memset(tmp, 0, MAX_STRING_LEN);
    host_int2string(logRecord->client_ip, logRecord->client_port, tmp);
    g_string_append_printf(dst, "C:%s ", tmp);

    g_string_append_printf(dst, "C_db:%s ", logRecord->client_db);
    g_string_append_printf(dst, "C_usr:%s ", logRecord->client_user);

    //server info
    memset(tmp, 0, MAX_STRING_LEN);
    host_int2string(logRecord->server_ip, logRecord->server_port, tmp);
    g_string_append_printf(dst, "S:%s(thread_id:%d) ", tmp, logRecord->thread_id);

    g_string_append_printf(dst, "S_db:%s ", logRecord->server_db);
    g_string_append_printf(dst, "S_usr:%s ", logRecord->server_user);

    //type bytes rows latency
    g_string_append_printf(dst,"inj(type:%d bytes:%d rows:%d) ", logRecord->type, logRecord->bytes, logRecord->rows);
    g_string_append_printf(dst, "%lf(ms) ", logRecord->latency);

    //OK
    g_string_append_printf(dst, "%s Query:", logRecord->state == 1?"OK":"ERR");

    //sql
    g_string_append_printf(dst, "%s%s", logRecord->annotation, logRecord->sql != NULL?logRecord->sql->str:"");
    if(flag & 0x1) {
        //prototype signature
        g_string_append_printf(dst, "prototype:%s ", logRecord->prototype != NULL?logRecord->prototype->str:"");
    }
    if(flag & 0x2) {
        g_string_append_printf(dst, "signature:%s", logRecord->signature);
    }
}
LOGRECORD newLogRecord(LOGRECORD p) {
    LOGRECORD record = (LOGRECORD)malloc(sizeof(LogRecord));
    if(record == NULL) return NULL;
    memset(record, 0, sizeof(LogRecord));
    record->client_ip = p->client_ip;
    record->client_port = p->client_port;
    memcpy(record->client_db, p->client_db, strlen(p->client_db));
    memcpy(record->client_user, p->client_user, strlen(p->client_user));
    record->server_ip = p->server_ip;
    record->server_port = p->server_port;
    memcpy(record->server_db, p->server_db, strlen(p->server_db));
    memcpy(record->server_user, p->server_user, strlen(p->server_user));
    record->thread_id = p->thread_id;
    record->type = p->type;
    record->bytes = p->bytes;
    record->rows = p->rows;
    record->latency = p->latency;
    record->state = p->state;
    record->sql = g_string_new(NULL);
    g_string_assign(record->sql, p->sql->str);
    record->prototype = g_string_new(NULL);
    g_string_assign(record->prototype, p->prototype->str);
    memcpy(record->signature, p->signature, strlen(p->signature));
    record->sql_type = SQL_TYPE_OTHER;

    record->log_time = p->log_time;
    record->sql_time = p->sql_time;
    record->log_us = p->log_us;
    record->sql_us = p->sql_us;
    return record;
}
void freeLogRecord(gpointer p) {
   if(p == NULL) return;
   LOGRECORD q = (LOGRECORD)p;
   if(q->sql) g_string_free(q->sql, TRUE); 
   if(q->prototype) g_string_free(q->prototype, TRUE); 
   free(q);
}
typedef struct _transInfo{
    int thread_id;
    int startTrans;
	int set_autocommit;
	struct tm sql_time;		 
	long sql_us;
	int count;
}TransInfo, *TRANSINFO;
TRANSINFO newTransInfo(LogRecord record) {
	TRANSINFO p = (TRANSINFO)malloc(sizeof(TransInfo));
	memset(p, 0, sizeof(TRANSINFO));
	p->thread_id = record.thread_id;
	p->startTrans = record.start_trans;
	p->sql_time = record.sql_time;
	p->count = 0;
	p->set_autocommit = record.set_autocommit;
	p->sql_us = record.sql_us;
	return p;
}
void freeTransInfo(gpointer p) {
	if(p) free(p);
}

LogRecord logRecord;
GHashTable *table_backend = NULL;
GHashTable *table_client = NULL;

GList *list_slow = NULL;
GList *list_threadId = NULL;
GList *list_prototype = NULL;
GList *list_latency = NULL;
long long latency_count[8] = {0};
GList *list_signature = NULL;

GList *list_trans = NULL;

void handle();
void check(int c) {
    switch(c) {
        case SQL_BEGIN: {
            if(logRecord.sql) g_string_free(logRecord.sql, TRUE);
            if(logRecord.prototype) g_string_free(logRecord.prototype, TRUE);
            memset(&logRecord, 0, sizeof(LogRecord));
            logRecord.sql = g_string_new(NULL);
            logRecord.prototype = g_string_new(NULL);
            logRecord.sql_type = SQL_TYPE_OTHER;
            memset(&(logRecord.sql_time),0,sizeof(logRecord.sql_time));
            memset(&(logRecord.log_time),0,sizeof(logRecord.log_time));
            setDate(yytext, &(logRecord.log_time));

            break;
        }
        case SQL_YEAR: {

            //init
            if(logRecord.sql) g_string_free(logRecord.sql, TRUE);
            if(logRecord.prototype) g_string_free(logRecord.prototype, TRUE); 
            memset(&logRecord, 0, sizeof(LogRecord));
            logRecord.sql = g_string_new(NULL);
            logRecord.prototype = g_string_new(NULL);
            logRecord.sql_type = SQL_TYPE_OTHER;
            memset(&(logRecord.sql_time),0,sizeof(logRecord.sql_time));
            memset(&(logRecord.log_time),0,sizeof(logRecord.log_time));

            setDate(yytext, &(logRecord.log_time));
            break;
        }
        case SQL_TIME: {
            setTime(yytext, &(logRecord.log_time));
            logRecord.log_us = getus(yytext);
            break;
        }
        case SQL_YEARB: {
            char tmp[MAX_STRING_LEN] = {""};
            get_second(yytext, tmp, ":");
            setDate(tmp, &(logRecord.sql_time));
            break;
        }
        case SQL_TIMEB: {
            setTime(yytext, &(logRecord.sql_time));
            logRecord.sql_us = getus(yytext);
            break;
        }
        case SQL_CLIENT: {
            char tmp[MAX_STRING_LEN] = {""};
            get_second(yytext, tmp, ":");
            host_string2int(tmp, &logRecord.client_ip, &logRecord.client_port);
            break;
        }
        case SQL_DBC: {
            char tmp[MAX_STRING_LEN] = {""};
            get_second(yytext, tmp, ":");
            if(tmp[0] == 0) {
                memcpy(logRecord.client_db, " ", strlen(" "));
            } else {
                memcpy(logRecord.client_db, tmp, strlen(tmp));
            }
            break;
        }
        case SQL_USERC: {
            char tmp[MAX_STRING_LEN] = {""};
            get_second(yytext, tmp, ":");
            if(tmp[0] == 0) {
                memcpy(logRecord.client_user, " ", strlen(" "));
            } else {
                memcpy(logRecord.client_user, tmp, strlen(tmp));
            }
            break;
        }
        case SQL_SERVER: {
            char tmp[MAX_STRING_LEN] = {""};
            get_second(yytext, tmp, ":");
            host_string2int(tmp, &logRecord.server_ip, &logRecord.server_port);
            break;
        }
        case SQL_ID: {
            char tmp[MAX_STRING_LEN] = {""};
            get_second(yytext, tmp, ":");
            logRecord.thread_id = atoi(tmp);
            break;
        }
        case SQL_DBS: {
            char tmp[MAX_STRING_LEN] = {""};
            get_second(yytext, tmp, ":");
            if(tmp[0] == 0) {
                memcpy(logRecord.server_db, " ", strlen(" "));
            } else {
                memcpy(logRecord.server_db, tmp, strlen(tmp));
            }
            break;
        }
        case SQL_USERS: {
            char tmp[MAX_STRING_LEN] = {""};
            get_second(yytext, tmp, ":");
            if(tmp[0] == 0) {
                memcpy(logRecord.server_user, " ", strlen(" "));
            } else {
                memcpy(logRecord.server_user, tmp, strlen(tmp));
            }
            break;
        }
        case SQL_TYPE: {
            char tmp[MAX_STRING_LEN] = {""};
            get_second(yytext, tmp, ":");
            logRecord.type = atoi(tmp);
            break;
        }
        case SQL_BYTES: {
            char tmp[MAX_STRING_LEN] = {""};
            get_second(yytext, tmp, ":");
            logRecord.bytes = atoi(tmp);
            break;
        }
        case SQL_ROWS: {
            char tmp[MAX_STRING_LEN] = {""};
            get_second(yytext, tmp, ":");
            logRecord.rows = atoi(tmp);
            break;
        }
        case SQL_LATENCY: {
            logRecord.latency = strtod(yytext, NULL);
            break;
        }
        case SQL_SLOW: {
            logRecord.slow = 1;
            break;
        }
        case SQL_LF: {
            break;
        }
        case SQL_END: {
            //log
            char *sig = g_compute_checksum_for_string(G_CHECKSUM_MD5, logRecord.prototype->str, logRecord.prototype->len);
            memcpy(logRecord.signature, sig, strlen(sig));
            handle();
            break; 
        }
        case SQL_STATE: {
            if(strcmp(yytext, "OK") == 0) {
                logRecord.state = 1;
            } else {
                logRecord.state = 0;
            }
            break;
        }
		case SQL_KEY_START_TRANS: {
			g_string_append_printf(logRecord.sql, "%s ", yytext);
			g_string_append_printf(logRecord.prototype, "%s ", yytext);
			logRecord.start_trans = 1;
			break;
		}
		case SQL_KEY_END_TRANS: {
			g_string_append_printf(logRecord.sql, "%s ", yytext);
			g_string_append_printf(logRecord.prototype, "%s ", yytext);
			logRecord.end_trans = 1;
			break;
		}
		case SQL_KEY_AUTOCOMMIT: {
			g_string_append_printf(logRecord.sql, "%s ", yytext);
			g_string_append_printf(logRecord.prototype, "%s ", yytext);
			logRecord.set_autocommit = 10;
			break;
		}
        case SQL_KEYWORD: {
            g_string_append_printf(logRecord.sql, "%s ", yytext);
            g_string_append_printf(logRecord.prototype, "%s ", yytext);
            if(strcasecmp(yytext, "insert") == 0 && sql_type_state[0]) {
                logRecord.sql_type = SQL_TYPE_INSERT;
                sql_type_state[0] = 0;
            } else if(strcasecmp(yytext, "delete") == 0 && sql_type_state[1]) {
                logRecord.sql_type = SQL_TYPE_DELETE;
                sql_type_state[1] = 0;
            } else if(strcasecmp(yytext, "update") == 0 && sql_type_state[2]) {
                logRecord.sql_type = SQL_TYPE_UPDATE;
                sql_type_state[2] = 0;
            } else if(strcasecmp(yytext, "select") == 0 && sql_type_state[3]) {
                logRecord.sql_type = SQL_TYPE_SELECT;
                sql_type_state[3] = 0;
            }
            break;
        }
        case SQL_IDENTIFIER: {
            g_string_append_printf(logRecord.sql, "%s ", yytext);
            g_string_append_printf(logRecord.prototype, "%s ", yytext);
            break;
        }
        case SQL_LEFTBRACKET: {
            g_string_append_printf(logRecord.sql, "%s ", yytext);
            g_string_append_printf(logRecord.prototype, "%s ", yytext);
            break;
        }
        case SQL_RIGHTBRACKET: {
            g_string_append_printf(logRecord.sql, "%s ", yytext);
            g_string_append_printf(logRecord.prototype, "%s ", yytext);
            break;
        }
        case SQL_TEXTSTRING: {
            g_string_append_printf(logRecord.sql, "%s ", yytext);
            g_string_append_printf(logRecord.prototype, "? ");
            break;
        }
        case SQL_COMMA: {
            g_string_append_printf(logRecord.sql, "%s ", yytext);
            g_string_append_printf(logRecord.prototype, "%s ", yytext);
            break;
        }
        case SQL_OPERATOR: {
            g_string_append_printf(logRecord.sql, "%s ", yytext);
            g_string_append_printf(logRecord.prototype, "%s ", yytext);
            break;
        }
        case SQL_SEMICOLON: {
            g_string_append_printf(logRecord.sql, "%s ", yytext);
            g_string_append_printf(logRecord.prototype, "%s ", yytext);
            break;
        }
        case SQL_VALUE: {
            g_string_append_printf(logRecord.sql, "%s ", yytext);
            g_string_append_printf(logRecord.prototype, "? ");
            break;
        }
        case SQL_SQL: {
            sql_type_state[0] = 1;
            sql_type_state[1] = 1;
            sql_type_state[2] = 1;
            sql_type_state[3] = 1;
			break;
        }
        case SQL_INVALID:
        case SQL_OTHER: {
            break;
        }
		case SQL_ANNOTATION: {
			memcpy(logRecord.annotation, yytext, strlen(yytext));
			break;
		}
        default: {
            break;
        }
    }
    return ;
}
char *help = "\
[参数含义]:\n\
      -b \"yyyy-mm-dd hh:mm:ss.ww\"    ## 开始时间\n\
      -e \"yyyy-mm-dd hh:mm:ss.ww\"    ## 结束时间\n\
      -f                             ## 格式化日志,必须和-i -o 配合使用\n\
      -i inputfile                   ## 输入文件\n\
      -o outputfile                  ## 输出文件\n\
      -w num                         ## 格式化文件中添加原型 -w 1 或添加指纹 -w 2, 或两者都添加,必须和-i -o -f配合使用\n\
      -s num                         ## 统计指定时间(没有指定时间则全文)最慢num条日志，num最大指定10000\n\
      -t num                         ## 按时间顺序统计大于num毫秒的所有日志,若num ==0 则进行全文统计\n\
      -p                             ## 按backend ip统计次数\n\
      -q                             ## 按client ip统计次数\n\
      -d num                         ## 统计thread-id 为num的日志,必须和-i -o配合使用\n\n\
      -j ip:port                     ## 按client 的ip:port 过滤日志\n\
      -l ip:port                     ## 按server 的ip:port 过滤日志\n\
      -k search-words                ## 按搜索包含search-words的所有SQL的日志\n\
      -a                             ## 按照指纹进行分析,必须和-i -o 配合使用\n\
      -m [a|s|c]                     ## 指纹分析时排序方式，依次为 按平均耗时 总耗时 数量\n\
      -x \"abcdef\"                    ## x后输入32位指纹,根据指纹过滤日志\n\
      -u [d|h|m|s]                   ## 间隔单位: 天 小时 分钟 秒\n\
      -n num                         ## 间隔数,必须和-u 配合使用\n\
      -c num                         ## 按类型过滤日志, num 1:insert 2:update 4:delete 8:select 16:other\n\
      -r                             ## 只抽取SQL语句\n\
\n[使用例子]:\n\
      %s -h  #help info \n\n\
      %s -i inputfile -o outputfile -f # 格式化日志 \n\
      %s -i inputfile -o outputfile -f -w 3 # 格式化日志并添加水印 \n\
      %s -b \"yyyy-mm-dd hh:mm:ss.ww\" -e \"yyyy-mm-dd hh:mm:ss.ww\" -i inputfile -o outputfile -f ## 按时间段格式化日志\n\
      %s -b \"yyyy-mm-dd hh:mm:ss.ww\" -e \"yyyy-mm-dd hh:mm:ss.ww\" -i inputfile -ooutputfile -a # 按指纹分析\n\
      %s -i inputfile -o outputfile -s 100 ## 统计最慢100条日志\n\
      %s -i inputfile -o outputfile -t 0 ## 统计各个区间内的日志数量\n\
      %s -i inputfile -o outputfile -t 100 ## 打印大于100ms 的日志\n\
      %s -i inputfile -o outputfile -p ## 按backend ip统计\n\
      %s -i inputfile -o outputfile -q ## 按client ip统计\n\
      %s -i inputfile -o outputfile -d 123 ## 输出thread-id为123的所有日志\n\
      %s -i inputfile -o outputfile -a -u m -n 5 ##指纹分析, 每5m分析一次\n\
      %s -i inputfile -o outputfile -a -m s ## 按照出现总时间来输出统计指纹\n\
      %s -i inputfile -o outputfile -x \"abcdef\" ## 输出指纹为 abcdef 的所有日志\n\
      %s -i inputfile -o outputfile -c 7 ## 过滤出insert update delete语句\n\
      %s -i inputfile -o outputfile -j 10.1.1.1:1234  ## 过滤来源是客户端为10.1.1.1:1234的日志\n\
      %s -i inputfile -o outputfile -l 10.1.1.1:1234  ## 过滤发往DB为10.1.1.1:1234的日志\n\
      %s -i inputfile -o outputfile -k \"set autocommit\"  ## 过滤SQL中包含set autocommit 的日志\n\
      %s -i inputfile -o outputfile -r ## 抽取SQL语句\n\
\n[说明]:\n\
      输出的每个.代表已经处理了约3万行日志\n\
      如果一段时间没有输出.,则可能输入文件有误或是文件内容格式有误\n\n\
      "; 
char *errMsg = "参数错误!\n";
long long timeBegin = -1;
long long timeEnd = -1;
long long timeNext = -1;

char unit = '\0';//间隔单位
int interval = -1;//间隔

int bFormat = 0;//是否format
int bAnalyze = 0;//是否按指纹分析
int bBackendIP = 0;//是否按bakcend ip统计
int bClientIP = 0;//是否按client ip统计
int bSlowLog = 0;//是否统计slow log
int bThreadId = 0;//是否统计thread id

char inputfile[MAX_STRING_LEN] = {""};
char outputfile[MAX_STRING_LEN] = {""};

int signature = 0;//是否添加指纹或prototype
int slowLog = 0;
int threadId = 0;
char sort_type = '\0';
double latencyStatistics = -1024;
char signature32[MAX_STRING_LEN] = {""};
int sqlFilter = 0;

char clientIP[MAX_STRING_LEN] = {""};
char serverIP[MAX_STRING_LEN] = {""};
char sqlKey[MAX_SQL_KEY_LEN] = {""};

int extractSQL = 0;

int checkTrans = 0;

int init = 0;
int checkTimeSatisfy(long long time) {
    int ret = 1;
    if(timeBegin >= 0) {
        if(time - timeBegin < 0) {
            ret = 0;
        }
    }
    if(timeEnd >= 0) {
        if(time - timeEnd > 0) {
            ret = 0;
        }
    }
    return ret;
}
gint my_compare(gconstpointer item1, gconstpointer item2) {
    LOGRECORD p1 = (LOGRECORD)item1;
    LOGRECORD p2 = (LOGRECORD)item2;
    if(p1->latency>p2->latency) {
        return -1;
    } else if(p1->latency<p2->latency){
        return 1;
    } else {
        return 0;
    }
}
void slow_callback(gpointer data, gpointer user_data) {
    LOGRECORD record = (LOGRECORD)data;
    GString *p = g_string_new(NULL);
    log_format_p(record, p, signature);
    fprintf(yyout, "%s\n", p->str);
    g_string_free(p, TRUE);
}
typedef struct _host_statistics {
    char host[MAX_STRING_LEN];
    long long count;
}hostStatistics, *HOSTSTATISTICS;

HOSTSTATISTICS newHostStatistics(const char * host) {
    if(host == NULL) return NULL;
    HOSTSTATISTICS p = (HOSTSTATISTICS)malloc(sizeof(hostStatistics));
    memset(p, 0, sizeof(hostStatistics));
    p->count = 1;
    memcpy(p->host, host, strlen(host));
    return p;
}
void freeHostStatistics(HOSTSTATISTICS p) {
    if(p) free(p);
}
void host_callback(gpointer key, gpointer value, gpointer user_data) {
    HOSTSTATISTICS p = (HOSTSTATISTICS)value;
    fprintf(yyout, "%s %ld\n", p->host, p->count);
}
void threadId_callback(gpointer data, gpointer user_data) {
    LOGRECORD record = (LOGRECORD)data;
    GString *p = g_string_new(NULL);
    log_format_p(record, p, signature);
    fprintf(yyout, "%s\n", p->str);
    g_string_free(p, TRUE);
}
long long time_int2long(int y, long long t) {
    long long ret = t/pow(10, 6) + y*pow(10, 6);
}
void changeTime(int i, char u) {
    if(i<=0) return;
    switch(u) {
        case 'd': {
            timeNext += i*24*3600;
            break;
        }
        case 'h': {
            timeNext += i*3600;
            break;
        } 
        case 'm': {
            timeNext += i*60;
            break;
        }
        case 's': {
            timeNext += i;
            break;
        }
        default: {
            timeNext += i*60;
            break;
        }
    }
}
long long time2int(int i, char u) {
    if(i<=0) return 0;
    switch(u) {
        case 'd': {
            return i*24*3600;
        }
        case 'h': {
            return i*3600;
        }
        case 'm': {
            return i*60;
        }
        case 's': {
            return i;
        }
        default:{
            return 0;
        }
    }
    return 0;
}
int isBoundary(long long t) {
    return (timeNext - t)>0?0:1;
}
void initNextTime(long long time) {
    if(timeBegin <= 0) {
        timeBegin = time;//time of first log 
    } else {
        timeBegin = timeBegin<time?time:timeBegin;
    }
    if(init == 0) {
        timeNext = timeBegin;
        changeTime(interval, unit);
        init = 1;
    }
}
typedef struct _log_prototype {
    char signature[MAX_STRING_LEN];
    long long  count;
    double latency_max;
    double latency_min;
    double latency_total;
}LogPrototype, *LOGPROTOTYPE;
int bHead = 0;
LOGPROTOTYPE newLogPrototype(LogRecord record) {
    LOGPROTOTYPE p = (LOGPROTOTYPE)malloc(sizeof(LogPrototype));
    memset(p, 0, sizeof(LogPrototype)); 
    mempcpy((char*)p->signature, (char*)record.signature, strlen(record.signature));
    p->count = 1;
    p->latency_max = record.latency;
    p->latency_min = record.latency;
    p->latency_total = record.latency;
    return p;
}
gint prototype_compare(gconstpointer item1, gconstpointer item2) { 
    LOGPROTOTYPE p1 = (LOGPROTOTYPE)item1;
    char *p2 = (char *)item2;
    return strcmp(p1->signature, p2);
}
gint trans_compare(gconstpointer item1, gconstpointer item2) {
	if(item1 == NULL || item2 == NULL) return -1;
	TRANSINFO p = (TRANSINFO)item1;
	int *q = (int *)item2;
	return *q == p->thread_id?0:-1;
} 
gint avg_latency_compare(gconstpointer item1, gconstpointer item2) {
    LOGPROTOTYPE p1 = (LOGPROTOTYPE)item1;
    LOGPROTOTYPE p2 = (LOGPROTOTYPE)item2;
    if(p1->latency_total/p1->count > p2->latency_total/p2->count) {
        return -1;
    } else if(p1->latency_total/p1->count == p2->latency_total/p2->count) {
        return 0;
    } else {
        return 1;
    }
}
gint sum_latency_compare(gconstpointer item1, gconstpointer item2) {
    LOGPROTOTYPE p1 = (LOGPROTOTYPE)item1;
    LOGPROTOTYPE p2 = (LOGPROTOTYPE)item2;
    if(p1->latency_total > p2->latency_total) {
        return -1;
    } else if(p1->latency_total == p2->latency_total) {
        return 0;
    } else {
        return 1;
    }
}
gint count_latency_compare(gconstpointer item1, gconstpointer item2) {
    LOGPROTOTYPE p1 = (LOGPROTOTYPE)item1;
    LOGPROTOTYPE p2 = (LOGPROTOTYPE)item2;
    if(p1->count > p2->count) {
        return -1;
    } else if(p1->count == p2->count) {
        return 0;
    } else {
        return 1;
    }
}
void trans_callback(gpointer data, gpointer user_data) {
	TRANSINFO p = (TRANSINFO)data;
	if(p->count>0) {
		char time[MAX_STRING_LEN] = {""};
		formatTick(mktime(&(p->sql_time)), time);
		fprintf(yyout, "thread_id: %10ld  maybe %5ld uncommitted last at %s.%ld\n", p->thread_id, p->count, time, p->sql_us);
	}
}
void prototype_callback(gpointer data, gpointer user_data) {
    LOGPROTOTYPE p = (LOGPROTOTYPE)data;
    if(bHead) {
        fprintf(yyout, "/*\n");
        char begin[MAX_STRING_LEN] = {""};
        char end[MAX_STRING_LEN] = {""};
        long long b = timeNext - time2int(interval, unit);
        formatTick(b, begin);
        formatTick(timeNext, end);
        fprintf(yyout, " *begin: %s    end: %s    step:%d%c\n", begin, timeBegin >= timeNext?"                   ":end, interval>0?interval:0, unit == '\0'?'m':unit);
        fprintf(yyout, " */\n");
        fprintf(yyout, "%32s %10s %8s %8s %8s %8s\n", "Signature", "Count", "Sum", 
                "Avg", "Max", "Min");
        bHead = 0;
    }
    fprintf(yyout, "%32s %10ld %.6lf %.6lf %.6lf %.6lf\n", 
                    p->signature?p->signature:"--", p->latency_total, p->count, 
                    p->count?(double)(p->latency_total)/p->count:0, 
                    p->latency_max, p->latency_min);
}
void latency_callback(gpointer data, gpointer user_data) {
    LOGRECORD p1 = (LOGRECORD)data;
    GString *p = g_string_new(NULL);
    log_format_p(p1, p, signature);
    fprintf(yyout, "%s\n", p->str);
    g_string_free(p, TRUE);
}
void signature_callback(gpointer data, gpointer user_data) {
    LOGRECORD p1 = (LOGRECORD)data;
    GString *p = g_string_new(NULL);
    log_format(logRecord, p, signature);
    fprintf(yyout, "%s\n", p->str);
    g_string_free(p, TRUE);
}
void freeLogPrototype(gpointer p) {
    if(p) free(p);
}
void updateLogPrototype(LOGPROTOTYPE p, LogRecord record) {
    if(p == NULL) return;
    p->count++;
    if(p->latency_max < record.latency) {
        p->latency_max = record.latency;
    }
    if(p->latency_min > record.latency) {
        p->latency_min = record.latency;
    }
    p->latency_total += record.latency;
}
int rangeCal(LogRecord record) {
    if(record.latency<pow(2, 0)) {
        return 0;
    } else if(record.latency>=pow(2, 0) && record.latency<pow(2, 1)) {
        return 1;
    } else if(record.latency>=pow(2, 1) && record.latency<pow(2, 2)) {
        return 2;
    } else if(record.latency>=pow(2, 2) && record.latency<pow(2, 3)) {
        return 3;
    } else if(record.latency>=pow(2, 3) && record.latency<pow(2, 4)) {
        return 4;
    } else if(record.latency>=pow(2, 4) && record.latency<pow(2, 5)) {
        return 5;
    } else if(record.latency>=pow(2, 5) && record.latency<pow(2, 6)) {
        return 6;
    } else if(record.latency>=pow(2, 6)) {
        return 7;
    }
}
long long dot = 0;
void handle() {
    //print dot
    if(++dot%30000 == 0) printf("."), fflush(stdout);
    if(dot%300000 == 0) printf(" "), fflush(stdout);
    //check time
    /*
    printf("%d, %ld, %ld\n", checkTimeSatisfy(mktime(&(logRecord.sql_time))), timeBegin, mktime(&(logRecord.sql_time)));
    if(!checkSatisfy(logRecord.begin_year, logRecord.begin_time)) {
        goto end;
    }
    */
    if(!checkTimeSatisfy(mktime(&(logRecord.sql_time)))) {
        goto end;
    }
    //filter slow log
    if(logRecord.slow == 1) {
        goto end;
    }
    //format 
    if(bFormat) {
        GString *p = g_string_new(NULL);
        log_format(logRecord, p, signature);
        fprintf(yyout, "%s\n", p->str);
        g_string_free(p, TRUE);
    } else if(bSlowLog){//-s
        LOGRECORD p = newLogRecord(&logRecord); 
        if(p == NULL) goto end;
        
        list_slow = g_list_insert_sorted(list_slow, p, my_compare);
        if(g_list_length(list_slow)>slowLog) {
            GList *q = (LOGRECORD)g_list_last(list_slow);
            LOGRECORD m = (LOGRECORD)q->data;
            if(m) list_slow = g_list_remove(list_slow, (LOGRECORD)(m));
            if(m) freeLogRecord(m);
        }
    } else if(bBackendIP) {
        char host[MAX_STRING_LEN] = {""};    
        host_int2string(logRecord.server_ip, logRecord.server_port, host);
        if(g_hash_table_contains(table_backend, host)) {
            HOSTSTATISTICS p = g_hash_table_lookup(table_backend, host);
            p->count++;
        } else {
            HOSTSTATISTICS q = newHostStatistics(host);
            g_hash_table_insert(table_backend, host, q);
        }
    } else if(bClientIP) {
        char host[MAX_STRING_LEN] = {""};
        host_int2string(logRecord.client_ip, logRecord.client_port, host);
        if(g_hash_table_contains(table_client, host)) {
            HOSTSTATISTICS p = g_hash_table_lookup(table_client, host);
            p->count++;
        } else {
            HOSTSTATISTICS q = newHostStatistics(host);
            g_hash_table_insert(table_client, host, q);
        }
    } else if(bThreadId) {
        if(logRecord.thread_id != threadId) goto end; 
        LOGRECORD p = newLogRecord(&logRecord);
        if(p) list_threadId = g_list_append(list_threadId, p);
    } else if(bAnalyze) {            
        if(init == 0) {
            initNextTime(mktime(&(logRecord.sql_time)));
        }        
        if(interval &&  !isBoundary(mktime(&(logRecord.sql_time)))) {

            //check whether exists
            GList *lt = g_list_find_custom(list_prototype, logRecord.signature, prototype_compare);
            if(lt == NULL) {
                LOGPROTOTYPE p = newLogPrototype(logRecord);
                if(p == NULL) goto end;
                //list_prototype = g_list_insert_sorted(list_prototype, p, my_compare); 
                list_prototype = g_list_append(list_prototype, p);
            } else {
                LOGPROTOTYPE p = (LOGPROTOTYPE)lt->data;
                updateLogPrototype(p, logRecord);
            }
        } else if (interval<=0) {
            GList *lt = g_list_find_custom(list_prototype, logRecord.signature, prototype_compare);
            if(lt == NULL) {
                LOGPROTOTYPE p = newLogPrototype(logRecord);
                if(p == NULL) goto end;
                //list_prototype = g_list_insert_sorted(list_prototype, p, my_compare); 
                list_prototype = g_list_append(list_prototype, p);
            } else {
                LOGPROTOTYPE p = (LOGPROTOTYPE)lt->data;
                updateLogPrototype(p, logRecord);
            }
        } else {
            //print
            if(g_list_length(list_prototype)) { 
                bHead = 1;
                switch(sort_type) {
                    case 'a': {
                        list_prototype = g_list_sort(list_prototype, avg_latency_compare);
                        break;
                    }
                    case 's': {
                        list_prototype = g_list_sort(list_prototype, sum_latency_compare);
                        break;
                    }
                    case 'c': {
                        list_prototype = g_list_sort(list_prototype, count_latency_compare);
                        break;
                    }
                    default: {
                        list_prototype = g_list_sort(list_prototype, count_latency_compare);
                        break;
                    }
                }
                g_list_foreach(list_prototype, prototype_callback, NULL);
                g_list_free_full(list_prototype, freeLogPrototype);
                list_prototype = NULL;
            }
            //change time
            changeTime(interval, unit);
        } 
    } else if(latencyStatistics >= 0) {

        if(latencyStatistics == 0) {
            int range = rangeCal(logRecord);
            latency_count[range]++;
        } else {
            if(latencyStatistics <= logRecord.latency) {
                LOGRECORD p = newLogRecord(&logRecord);
                if(p) list_latency = g_list_append(list_latency, p);
            }
        }
    } else if(signature32[0] != '\0') {
        if(strcmp(logRecord.signature, signature32) == 0) {
            GString *p = g_string_new(NULL);
            log_format(logRecord, p, signature);
            fprintf(yyout, "%s\n", p->str);
            g_string_free(p, TRUE);
        }
    } else if(sqlFilter > 0) {
        switch(logRecord.sql_type) {
            case SQL_TYPE_INSERT: {
                if(check_insert(sqlFilter)) {
                    GString *p = g_string_new(NULL);
                    if(p == NULL) break;
                    log_format(logRecord, p, signature);
                    fprintf(yyout, "%s\n", p->str);
                    g_string_free(p, TRUE);
                }
                break;
             }
             case SQL_TYPE_UPDATE: {
                if(check_update(sqlFilter)) {
                    GString *p = g_string_new(NULL);
                    if(p == NULL) break;
                    log_format(logRecord, p, signature);
                    fprintf(yyout, "%s\n", p->str);
                    g_string_free(p, TRUE);
                }
                break;
             }
             case SQL_TYPE_DELETE: {
                if(check_delete(sqlFilter)) {
                    GString *p = g_string_new(NULL);
                    if(p == NULL) break;
                    log_format(logRecord, p, signature);
                    fprintf(yyout, "%s\n", p->str);
                    g_string_free(p, TRUE);
                }
                break;
             }
             case SQL_TYPE_SELECT: {
                if(check_select(sqlFilter)) {
                    GString *p = g_string_new(NULL);
                    if(p == NULL) break;
                    log_format(logRecord, p, signature);
                    fprintf(yyout, "%s\n", p->str);
                    g_string_free(p, TRUE);
                }
                break;
             }
             case SQL_TYPE_OTHER: {
                if(check_other(sqlFilter)) {
                    GString *p = g_string_new(NULL);
                    if(p == NULL) break;
                    log_format(logRecord, p, signature);
                    fprintf(yyout, "%s\n", p->str);
                    g_string_free(p, TRUE);
                }
                break;
             }
        }
    } else if(clientIP[0]!='\0') {
		char host[MAX_STRING_LEN] = {""};
		host_int2string(logRecord.client_ip, logRecord.client_port, host);
		char *pos = strcasestr(host, clientIP);
		if(pos != NULL) {
			GString *p = g_string_new(NULL);
			log_format(logRecord, p, signature);
			fprintf(yyout, "%s\n", p->str);
			g_string_free(p, TRUE);			
		}
	} else if(serverIP[0]!='\0') {
		char host[MAX_STRING_LEN] = {""};
		host_int2string(logRecord.server_ip, logRecord.server_port, host);
		char *pos = strcasestr(host, serverIP);
		if(pos != NULL) {
			GString *p = g_string_new(NULL);
			log_format(logRecord, p, signature);
			fprintf(yyout, "%s\n", p->str);
			g_string_free(p, TRUE);
		}
	} else if(sqlKey[0]!='\0') {
		char *pos = strcasestr(logRecord.sql->str, sqlKey);
		if(pos != NULL) {
			GString *p = g_string_new(NULL);
			log_format(logRecord, p, signature);
			fprintf(yyout, "%s\n", p->str);
			g_string_free(p, TRUE);			
		}
	} else if(extractSQL) {
		fprintf(yyout, "%s\n", logRecord.sql->str);
	} else if(checkTrans) {
		//检查隐式事务
		if(logRecord.set_autocommit == 10) {
			char *pos = strcasestr(logRecord.sql->str, "set autocommit = 1");
			if(pos) {
				logRecord.set_autocommit = 1;
			} else {
				logRecord.set_autocommit = 0;
			}
			GList *lt = g_list_find_custom(list_trans, &logRecord.thread_id, trans_compare);					
			if(lt == NULL) {
				TRANSINFO p = newTransInfo(logRecord);
				list_trans = g_list_append(list_trans, p);
			} else {
				//设置隐式事务标志
				TRANSINFO p = (TRANSINFO)lt->data;
				p->set_autocommit = logRecord.set_autocommit;
				//如果有未提交的事务，将隐式事务转换成显示事务
				if(p->set_autocommit == 1 && p->count > 0) {
					p->startTrans = 1;
				}
			}
		} else if(logRecord.start_trans) {//检查显示事务
			GList *lt = g_list_find_custom(list_trans, &logRecord.thread_id, trans_compare);					
			if(lt == NULL) {
				TRANSINFO p = newTransInfo(logRecord);
				list_trans = g_list_append(list_trans, p);
			} else {
				//清空计数器，设置显示事务
				TRANSINFO p = (TRANSINFO)lt->data;
				p->startTrans = 1;
				//之前的事务全部提交
				p->count = 0;
			}
		} else if(logRecord.end_trans) {//无论显示隐式事务都需要commit
			GList *lt = g_list_find_custom(list_trans, &logRecord.thread_id, trans_compare);					
			if(lt == NULL) {
				//do nothing
			} else {
				TRANSINFO p = (TRANSINFO)lt->data;
				p->startTrans = 0;//显示事务结束
				p->count = 0;//唯一清除计数器
			}
		} else {
			GList *lt = g_list_find_custom(list_trans, &logRecord.thread_id, trans_compare);					
			if(lt == NULL) {
				//do nothing
			} else {
				TRANSINFO p = (TRANSINFO)lt->data;
				if(p->startTrans || p->set_autocommit == 0) {
					p->sql_time = logRecord.sql_time;
					p->sql_us = logRecord.sql_us;
					p->count++;
				}
			}
		}
	}
end:
    //check time
    return;
}
int checkYearFormat(const char * src) {
    if(src == NULL) return;
    int ret = 0;
    int loop = 0, len;
    len = strlen(src);
    for(loop = 0; loop < len; loop++) {
        if(src[loop] == '-') {
            ret++;
        }
    }
    return (ret == 2);
}
int checkTimeFormat(const char * src) {
    if(src == NULL) return;
    int com = 0, dot = 0;
    int loop = 0, len = 0;
    len = strlen(src);
    for(loop = 0; loop<len; loop++) {
        if(src[loop] == ':') {
            com++;
        }
        if(src[loop] == '.') {
            dot++;
        }
    }
    return (dot==1)&&(com==2);
}
int main(int argc, char **argv) {
    int c, ch;
    while((ch = getopt(argc, argv, "zrafhpqw:i:o:b:e:s:d:m:t:x:c:n:u:j:l:k:")) != -1) {
        switch(ch) {
            case 'h': {
                printf(help, argv[0], argv[0], argv[0], argv[0],argv[0],
                argv[0], argv[0], argv[0], argv[0], argv[0], 
                argv[0], argv[0], argv[0], argv[0], argv[0],
				argv[0], argv[0], argv[0], argv[0]);
                exit(1);
            }
            case 'f': {
                bFormat = 1;
                break;
            }
            case 'b': {
                if(checkTime(optarg)) {
                    timeBegin = getTick(optarg);    
                } else {
                    printf("%s", errMsg);
                    exit(1);
                }
                break;
            }
            case 'e': {
                if(checkTime(optarg)) {
                    timeEnd = getTick(optarg);    
                } else {
                    printf("%s", errMsg);
                    exit(1);
                }
                break;
            }
            case 'i': {
                memcpy(inputfile, optarg, strlen(optarg));
                break;
            }
            case 'o': {
                memcpy(outputfile, optarg, strlen(optarg));
                break;
            }
            case 'w': {
                if(optarg == NULL) {
                    printf("%s", errMsg);
                    exit(1);
                }
                signature = atoi(optarg);
                break;
            }
            case 's': {
                bSlowLog = 1;
                slowLog = atoi(optarg);
                if(slowLog > 10000) {
                    slowLog = 10000;
                }
                break;
            }
            case 'p': {
                bBackendIP = 1;
                break;
            }
            case 'q': {
                bClientIP = 1;
                break;
            }
            case 'd': {
                bThreadId = 1;
                threadId = atoi(optarg);
                break;
            }
            case 'n': {
                interval = atoi(optarg);
                break;
            }
            case 'u': {
                switch(optarg[0]) {
                    case 'd':
                    case 'h':
                    case 'm':
                    case 's': {
                        unit = optarg[0];
                        break;
                    }
                    default: {
                        printf("%s", errMsg);
                        exit(1);
                    }
                 }
                 break;
             }
             case 'a': {
                 bAnalyze = 1;
                 break;
             }
             case 'm': {
                 switch(optarg[0]) {
                    case 'a':
                    case 's':
                    case 'c': {
                        sort_type = optarg[0];
                        break;
                    }
                    default: {
                        printf("%s", errMsg);
                        exit(1);
                    }
                 }
                 break;
             }
             case 't': {
                 latencyStatistics = atof(optarg);
                 if(latencyStatistics<0) {
                    latencyStatistics = 0.0;
                 }
                 break;
             }
             case 'x': {
                if(optarg[0] == '\0') {
                    printf("%s", errMsg);
                    exit(1);
                }
                memcpy(signature32, optarg, strlen(optarg));
                break;
             }            
             case 'c': {
                sqlFilter = atoi(optarg);        
                break;
             }
			 case 'j': {
				memcpy(clientIP, optarg, strlen(optarg));
				break;
			 }
			 case 'l': {
				memcpy(serverIP, optarg, strlen(optarg));
				break;
			 }
			 case 'k': {
				memcpy(sqlKey, optarg, strlen(optarg));
				break;
			 }
			 case 'r': {
				extractSQL = 1;				
				break;
			 }
			 case 'z': {
				checkTrans = 1;
				break;
		     }
         }//~switch
    }//~while
    //must have -i -o
    if(inputfile[0] == 0 || outputfile[0] == 0) {
        printf("%s", errMsg);
        exit(1);
    }
    //unit interval together
    if((unit != '\0' && interval == -1) ||(unit == '\0' && interval != -1)) {
        printf("%s", errMsg);
        exit(1);
    }

    yyin= fopen(inputfile, "r");
    yyout  = fopen(outputfile, "w");

    //init
    table_backend = g_hash_table_new(g_str_hash, g_str_equal);
    table_client = g_hash_table_new(g_str_hash, g_str_equal);
    while(c = yylex()) {
        check(c);
    }

    char *sig = g_compute_checksum_for_string(G_CHECKSUM_MD5, logRecord.prototype->str, logRecord.prototype->len);
    memcpy(logRecord.signature, sig, strlen(sig));
    handle();

    if(bFormat) {
    
    } else if(bSlowLog) {
       g_list_foreach(list_slow, slow_callback, NULL); 
       g_list_free_full(list_slow, freeLogRecord);
    } else if(bBackendIP) {
       g_hash_table_foreach(table_backend, host_callback, NULL);
       g_hash_table_destroy(table_backend);
    } else if(bClientIP) {
       g_hash_table_foreach(table_client, host_callback, NULL);
       g_hash_table_destroy(table_client);
    } else if(bThreadId) {
       g_list_foreach(list_threadId, threadId_callback, NULL);
       g_list_free_full(list_threadId, freeLogRecord);
    } else if(bAnalyze) {
       if(g_list_length(list_prototype)) {
           bHead = 1;
           switch(sort_type) {
                case 'a': {
                    list_prototype = g_list_sort(list_prototype, avg_latency_compare);
                    break;
                }
                case 's': {
                    list_prototype = g_list_sort(list_prototype, sum_latency_compare);
                    break;
                }
                case 'c': {
                    list_prototype = g_list_sort(list_prototype, count_latency_compare);
                    break;
                }
                default: {
                    list_prototype = g_list_sort(list_prototype, count_latency_compare);
                    break;
                }
           }
           g_list_foreach(list_prototype, prototype_callback, NULL);
           g_list_free_full(list_prototype, freeLogPrototype);
           list_prototype = NULL;
       } 
    } else if(latencyStatistics >=0) {
        if(latencyStatistics == 0) {
            fprintf(yyout, "[0,  1) %10ld\n", latency_count[0]);
            fprintf(yyout, "[1,  2) %10ld\n", latency_count[1]);
            fprintf(yyout, "[2,  4) %10ld\n", latency_count[2]);
            fprintf(yyout, "[4,  8) %10ld\n", latency_count[3]);
            fprintf(yyout, "[8, 16) %10ld\n", latency_count[4]);
            fprintf(yyout, "[16,32) %10ld\n", latency_count[5]);
            fprintf(yyout, "[32,64) %10ld\n", latency_count[6]);
            fprintf(yyout, "[64, +) %10ld\n", latency_count[7]);
        } else {
            g_list_foreach(list_latency, latency_callback, NULL);
            g_list_free_full(list_latency, freeLogRecord);
            list_latency = NULL;
        }
    } else if(signature32[0] != '\0') {
        
    } else if(checkTrans) {
		g_list_foreach(list_trans, trans_callback, NULL);
		g_list_free_full(list_trans, freeTransInfo);
		list_trans = NULL;
	}
    fclose(yyin);
    fclose(yyout);
    printf("\n");
    return 1;
}
