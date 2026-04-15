bison -d -v parser.y
flex lexical.l
gcc -o tester.exe lex.yy.c parser.tab.c -lfl

