#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#define MAX_STRING_LEN 1024
char inputfile1[MAX_STRING_LEN] = {""};
char inputfile2[MAX_STRING_LEN] = {""};
char outputfile[MAX_STRING_LEN] = {""};
FILE *fd1 = NULL;
FILE *fd2 = NULL;
FILE *fd3 = NULL;
int result = 1;
long long count = 0;
char GetNextChar(FILE * fd) {
    char ret = '\0';
    do {
        ret = fgetc(fd);
    }while(!feof(fd) && (ret == '\n' || ret == ' ' || ret == '\t'));
    return ret;
}
int main(int argc, char **argv) {
    int ch;
    while((ch = getopt(argc, argv, "i:c:o:h")) != -1) {
        switch(ch) {
            case 'i': {
                memcpy(inputfile1, optarg, strlen(optarg));
                break;
            }
            case 'c': {
                memcpy(inputfile2, optarg, strlen(optarg));
                break;
            }
            case 'o': {
                memcpy(outputfile, optarg, strlen(optarg));
                break;
            }
            case 'h': {
                printf("Usage:\n\
    argv[0] -i inputfile1 -c inputfile2 -o outputfile  ##对比inputfile1 inputfile2内容 \n\
                \n\n");
                exit(1);
            }
            default: {
                printf("参数错误!\n");
                exit(1);
            }
        }
    }
    //参数检查
    if(inputfile1[0] == 0 || inputfile2[0] == 0 || outputfile[0] == 0) {
        printf("参数错误!\n");
        exit(1);
    }
    //打开文件
    fd1 = fopen(inputfile1, "r");
    fd2 = fopen(inputfile2, "r");
    fd3 = fopen(outputfile, "w");
    if(fd1 == NULL || fd2 == NULL || fd3 == NULL) {
        printf("打开文件失败\n");
        exit(1);
    }
    //比较
    while(!feof(fd1) && !feof(fd2)) {
        char i = GetNextChar(fd1);
        char c = GetNextChar(fd2);
        if(i != c) {
            result = 0;
            break;
        }
        fputc(i, fd3);

        if(++count%30000000 == 0) {
            printf(".");
            fflush(stdout);
        }
        if(count%300000000 == 0) {
            printf(" ");
            fflush(stdout);
        }
        if(count%1000 == 0) {
            fputc('\n', fd3);
        }
    }
    if(result == 1) {
        printf("%s 与 %s 内容一致\n", inputfile1, inputfile2); 
    }else {
        printf("%s 与 %s 内容不一致\n", inputfile1, inputfile2);
    }
    fclose(fd1);
    fclose(fd2);
    fclose(fd3);
    return 0;
}
