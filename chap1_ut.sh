#!/bin/bash
#
# Unit Test script for chap1 program
# See Backup Strategy and Log of Example Run at end of script
#

#
# Make the exe then run the unit test cases
#

name=chap1
echo "making $name"
make clean
make

#
# Run test cases, save results, diff with previous result.
# Redirection of stdout, stderr to result file follows closing brace below
#

echo -e "\nRunning $name Test Cases - Saving results to ${name}_ut.rs1.\n"

{
echo -e "./$name <<< \")load ${name}_ut.input1\""
./$name <<< ")load ${name}_ut.input1" 
} > ${name}_ut.rs1 2>&1

echo -e "Rebuilding with smaller sizes to test error cases."
make testsize
echo -e "Running Tests that exceed sizes and appending results to ${name}_ut.rs1.\n"

{
echo -e "./$name <<< \")load ${name}_ut.input2\""
./$name <<< ")load ${name}_ut.input2" 
} >> ${name}_ut.rs1 2>&1

echo -e "Rebuilding with normal size limits for remaining test cases."
make clean
make

echo -e "\nNested load test: Use load command to read a file containing a load command."
echo -e "An error will be displayed and the program aborts."
echo -e "Running Nested load test and appending results to ${name}_ut.rs1.\n"
{
echo -e "./$name <<< \")load ${name}_ut.input3\""
./$name <<< ")load ${name}_ut.input3" 
} >> ${name}_ut.rs1 2>&1

echo -e "Nested sload test: Use load command to read a file containing a sload command."
echo -e "An error will be displayed and the program aborts."
echo -e "Running Nested sload test and appending results to ${name}_ut.rs1.\n"
{
echo -e "./$name <<< \")load ${name}_ut.input4\""
./$name <<< ")load ${name}_ut.input4" 
} >> ${name}_ut.rs1 2>&1


echo -e "Running load command for file that does not exist."
echo -e "Appending results to ${name}_ut.rs1.\n"
{
echo -e "\n\nTest an open file error\n\n"
echo -e "./$name <<< \")load does_not_exist.txt\""
./$name <<< ")load does_not_exist.txt" 
} >> ${name}_ut.rs1 2>&1

#
# Diff Results
# Below we compare current result (.rs1) with previous good result (.rs0).
#

echo -e "diff current result ${name}_ut.rs1 with last validated result ${name}_ut.rs0."
diff -qs ${name}_ut.rs1 ${name}_ut.rs0

#
# Backup Strategy
# If diffs are valid then copy .rs1 to .rs0 and save .rs0 as latest good result.
# Backup Makefile, source, UT script, inputs and result (.rs0) together.
# 
#
# Log of running this script
#
# $ ./chap1_ut.sh
# making chap1
# rm -fv chap1 *.o lex.yy.c chap1.tab.c chap1.tab.h
# removed 'chap1'
# removed 'ch1_info.o'
# removed 'chap1.tab.o'
# removed 'lex.yy.o'
# removed 'lex.yy.c'
# removed 'chap1.tab.c'
# removed 'chap1.tab.h'
# bison -d chap1.y
# gcc  -c chap1.tab.c
# flex chap1.l
# gcc  -c lex.yy.c
# gcc  -c ch1_info.c
# gcc  -o chap1 chap1.tab.o lex.yy.o ch1_info.o -ly -ll -lm
# 
# Running chap1 Test Cases - Saving results to chap1_ut.rs1.
# 
# Rebuilding with smaller sizes to test error cases.
# rm -fv chap1 *.o lex.yy.c chap1.tab.c chap1.tab.h
# removed 'chap1'
# removed 'ch1_info.o'
# removed 'chap1.tab.o'
# removed 'lex.yy.o'
# removed 'lex.yy.c'
# removed 'chap1.tab.c'
# removed 'chap1.tab.h'
# make CFLAGS="-DTESTSIZE"
# make[1]: Entering directory '/home/dawsond/lexyacc/chap1'
# bison -d chap1.y
# gcc -DTESTSIZE -c chap1.tab.c
# flex chap1.l
# gcc -DTESTSIZE -c lex.yy.c
# gcc -DTESTSIZE -c ch1_info.c
# gcc -DTESTSIZE -o chap1 chap1.tab.o lex.yy.o ch1_info.o -ly -ll -lm
# make[1]: Leaving directory '/home/dawsond/lexyacc/chap1'
# Running Tests that exceed sizes and appending results to chap1_ut.rs1.
# 
# Rebuilding with normal size limits for other test cases.
# rm -fv chap1 *.o lex.yy.c chap1.tab.c chap1.tab.h
# removed 'chap1'
# removed 'ch1_info.o'
# removed 'chap1.tab.o'
# removed 'lex.yy.o'
# removed 'lex.yy.c'
# removed 'chap1.tab.c'
# removed 'chap1.tab.h'
# bison -d chap1.y
# gcc  -c chap1.tab.c
# flex chap1.l
# gcc  -c lex.yy.c
# gcc  -c ch1_info.c
# gcc  -o chap1 chap1.tab.o lex.yy.o ch1_info.o -ly -ll -lm
# 
# Nested load test: Use load command to read a file containing a load command.
# An error will be displayed and the program aborts.
# Running Nested load test and appending results to chap1_ut.rs1.
# 
# Nested sload test: Use load command to read a file containing a sload command.
# An error will be displayed and the program aborts.
# Running Nested sload test and appending results to chap1_ut.rs1.
# 
# diff current result chap1_ut.rs1 with last validated result chap1_ut.rs0.
# Files chap1_ut.rs1 and chap1_ut.rs0 are identical
