#
# Makefile for "chap1"
#
SHELL = /bin/bash
LEX = flex
YACC = bison
CC = gcc

# Default CFLAGS empty
CFLAGS =

chap1: chap1.tab.o lex.yy.o ch1_info.o
	${CC} ${CFLAGS} -o chap1 chap1.tab.o lex.yy.o ch1_info.o -ly -ll -lm

lex.yy.o: lex.yy.c chap1.tab.h ch1_info.h
	${CC} ${CFLAGS} -c lex.yy.c

chap1.tab.o: chap1.tab.c chap1.tab.h ch1_info.h
	${CC} ${CFLAGS} -c chap1.tab.c

ch1_info.o: ch1_info.c ch1_info.h
	${CC} ${CFLAGS} -c ch1_info.c

chap1.tab.c chap1.tab.h: chap1.y ch1_info.h
	${YACC} -d chap1.y

lex.yy.c: chap1.l ch1_info.h
	${LEX} chap1.l

.PHONY: clean testsize

clean:
	rm -fv chap1 *.o lex.yy.c chap1.tab.c chap1.tab.h

testsize: clean
	$(MAKE) CFLAGS="-DTESTSIZE"
