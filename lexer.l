%{
#include <stdio.h>
#include <string.h>
#include "parser.tab.h"

int line = 1;
int column = 1;
%}


DIGIT       [0-9]
LETTER      [a-zA-Z_]
WHITESPACE  [ \t]

%%

"int"       { column += strlen(yytext); return INT; }
"float"     { column += strlen(yytext); return FLOAT; }
"double"    { column += strlen(yytext); return DOUBLE; }
"char"      { column += strlen(yytext); return CHAR; }
"String"    { column += strlen(yytext); return STRING; }
"boolean"   { column += strlen(yytext); return BOOLEAN; }
"final"     { column += strlen(yytext); return FINAL; }
"if"        { column += strlen(yytext); return IF; }
"break"        { column += strlen(yytext); return BREAK; }
"else"      { column += strlen(yytext); return ELSE; }
"switch"    { column += strlen(yytext); return SWITCH; }
"case"      { column += strlen(yytext); return CASE; }
"do"        { column += strlen(yytext); return DO; }
"while"     { column += strlen(yytext); return WHILE; }
"for"       { column += strlen(yytext); return FOR; }
"try"       { column += strlen(yytext); return TRY; }
"catch"     { column += strlen(yytext); return CATCH; }
"class"     { column += strlen(yytext); return CLASS; }
"public"    { column += strlen(yytext); return PUBLIC; }
"static"    { column += strlen(yytext); return STATIC; }
"void"      { column += strlen(yytext); return VOID; }
"new"       { column += strlen(yytext); return NEW; }
"import"    { column += strlen(yytext); return IMPORT; }
"System.out.println" { column += strlen(yytext); return PRINTLN; }

{DIGIT}+                    { column += strlen(yytext); yylval.str = strdup(yytext); return INTEGER_LITERAL; }
{DIGIT}+\.{DIGIT}+          { column += strlen(yytext); yylval.str = strdup(yytext); return FLOAT_LITERAL; }
\'.\'                       { column += strlen(yytext); yylval.str = strdup(yytext); return CHAR_LITERAL; }
\"[^\"]*\"                  { column += strlen(yytext); yylval.str = strdup(yytext); return STRING_LITERAL; }
"true"                      { column += strlen(yytext); yylval.str = strdup(yytext); return BOOLEAN_LITERAL; }
"false"                     { column += strlen(yytext); yylval.str = strdup(yytext); return BOOLEAN_LITERAL; }

{LETTER}({LETTER}|{DIGIT})* { column += strlen(yytext); yylval.str = strdup(yytext); return IDENTIFIER; }

"+"         { column++; return PLUS; }
"-"         { column++; return MINUS; }
"*"         { column++; return MULTIPLY; }
"/"         { column++; return DIVIDE; }
"="         { column++; return ASSIGN; }
"=="        { column += 2; return EQUAL; }
"!="        { column += 2; return NOT_EQUAL; }
"<"         { column++; return LESS; }
">"         { column++; return GREATER; }
"<="        { column += 2; return LESS_EQUAL; }
">="        { column += 2; return GREATER_EQUAL; }
"!"         { column++; return NOT; }
"("         { column++; return LPAREN; }
")"         { column++; return RPAREN; }
"{"         { column++; return LBRACE; }
"}"         { column++; return RBRACE; }
"["         { column++; return LBRACKET; }
"]"         { column++; return RBRACKET; }
";"         { column++; return SEMICOLON; }
","         { column++; return COMMA; }
"."         { column++; return DOT; }
":"         { column++; return COLON; }

{WHITESPACE}+               { column += strlen(yytext); }
\n                          { line++; column = 1; }
"//".*                      { column += strlen(yytext); }
"/*"([^*]|\*+[^*/])*\*+"/"  { char *s = yytext; while(*s) { if(*s++ == '\n') line++; } column = 1; }

.           { printf("Error: Invalid character '%s' at line %d, column %d\n", yytext, line, column); column++; }

%%

int yywrap() {
    return 1;
}
