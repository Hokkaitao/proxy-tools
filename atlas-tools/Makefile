analyzer:lex.yy.c
	gcc -oanalyzer lex.yy.c -lfl `pkg-config --cflags --libs glib-2.0`
compile:parser.l
	flex parser.l
compare:compare.c
	gcc -ocompare.c compare
clear:
	rm -rf compare lex.yy.c analyzer
