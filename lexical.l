%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "ts.h"
#include "parser.tab.h"


extern YYSTYPE yylval;
int nb_ligne = 1;   //le nombre de ligne doit etre initialise a 1
int nb_colonne = 1; //pour calculer le nombre de colonnes
int str_length = 0; //c'est la longeur de l'entite lexicale, elle sera utilisee 
        	        //pour calculer le nombre de colonne ou se trouve l'erreur syntaxique
                    
char chaine_ent[40]; //pour conserver l'entier sous forme d'une chaine de caracteres
int i; //indice pour parcourir chaine_ent
%}

chiffre0 [0-9]
chiffre1 [1-9]

ADDADD "++"
SUBSUB "--"
ADDEGAL "+="
ADD  "+"
SUB  "-"
MUL  "*"
DIV  "/"
DIVE "%"

AND "&&"
OR  "||"
NOT "!"

BG  ">"
BL  "<"
BGE ">="
BLE "<="
BE  "=="
BNE "!="


int 0|{chiffre1}{chiffre0}*|[+-](0|{chiffre1}{chiffre0}*)|"("[+-](0|{chiffre1}{chiffre0}*)")"

float "("[+-]?({chiffre1}{chiffre0}*|0)"\."{chiffre0}*{chiffre1}[fF]")"|[+-]?({chiffre1}{chiffre0}*|0)"\."{chiffre0}*{chiffre1}[fF]

double ("("[+-]?({chiffre1}{chiffre0}*|0)"\."{chiffre0}*{chiffre1}")")|[+-]?({chiffre1}{chiffre0}*|0)"\."{chiffre0}*{chiffre1}


setter "set"[A-Z][a-z|A-Z|{chiffre0}|_|$]*

getter "get"[A-Z][a-z|A-Z|{chiffre0}|_|$]*

char "'"[^']"'"

string (\"[^"]*\")

boolean "true"|"false"

idf ([A-Z|a-z|_|$])([A-Z]|[a-z]|{chiffre0}|_|$)*

commentaire ("//".*)|("/*"([^*]|\*+[^*/])*\*+"/")


%%

"public"         {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return PUBLIC;}
"private"		 {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return PRIVATE;}
"protected"		 {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return PROTECTED;}
"static"         {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return STATIC;}
"abstract"       {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return ABSTRACT;}
"void"           {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return VOID;}
"class"          {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return CLASS;}
"this"			 {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return THIS;}
"new"			 {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return NEW;}
"int"            {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return INT;}
"float"          {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return FLOAT;}
"double"         {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return DOUBLE;}
"char"           {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return CHAR;}
"string"         {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return STRING;}
"boolean"        {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return BOOLEAN;}
"final"          {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return FINAL;}
"if"             {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return IF;}
"else"           {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return ELSE;}
"for"            {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return FOR;}
"do"             {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return DO;}
"while"          {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return WHILE;}
"switch"         {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return SWITCH;}
"case"           {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return CASE;}
"default"        {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return DEFAULT;}
"break"          {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return BREAK;}
"return"         {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return RETURN;}
"try"            {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return TRY;}
"catch"          {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return CATCH;}
"finally"        {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return FINALLY;}
"throw"          {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return THROW;}
"System.out.println"  {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return PRINT;}

{int}   {
	    //si notre entier (sachant qu'il est stocke dans le tableau yytext) est ecrit entre parentheses
	    //alors on doit le recuperer dans la chaine sousChaine pour le traiter
	    if(yytext[0] == '('){
		    for(i = 0; i < yyleng - 2; i++)
		    {
			  chaine_ent[i] = yytext[i+1];
		    }
		    i = strlen(chaine_ent) - 1;   //pour avoir la taille de l'entier on doit enlever le signe "-" ou "+"
	    }

	    else {
		    strcpy(chaine_ent,yytext);
		    i = strlen(chaine_ent);       //ici on a pas besoin d'enlever le signe, car l'entier n'est pas signe
	    }

	    if( (i > 5) || atoi(chaine_ent) < (-32768) || atoi(chaine_ent) > (+32767) ) {
		    printf("Erreur lexicale {ligne %d; colonne %d} : entite '%s' ; un nombre entier doit etre entre -32768 et 32767\n", nb_ligne, nb_colonne + 1, yytext);
		    for(i = 0; i < strlen(chaine_ent); i++) {chaine_ent[i] =' ' ;}
		    //yyterminate();
	    }

	    else{
		    nb_colonne+=yyleng;
		    str_length = yyleng;
            yylval.chaine=strdup(yytext);
		    for(i = 0; i < strlen(chaine_ent); i++) {chaine_ent[i] = ' ';}
		    return ENTIER;
		}
}

{float}   {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return REEL_F;}
{double}  {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return REEL_D;}
{char}    {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return CAR;}
{string}  {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return STR;}
{boolean} {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return BOOL;}
{setter}  {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return SETTER;}
{getter}  {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return GETTER;}
{commentaire}

{ADDADD}  {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return ADDADD;}  
{SUBSUB}  {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return SUBSUB;}
{ADDEGAL} {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return ADDEGAL;}
{ADD}     {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return ADD;}
{SUB}     {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return SUB;}
{MUL}     {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return MUL;}
{DIV}     {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return DIV;}
{DIVE}    {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return DIVE;}

{AND} {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return AND;}
{OR}  {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return OR;}
{NOT} {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return NOT;}

{BG}    {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return BG;}
{BL}    {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return BL;}
{BGE}   {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return BGE;}
{BLE}   {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return BLE;}
{BE}    {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return BE;}
{BNE}   {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return BNE;}

[;,:{}()='] {nb_colonne+=yyleng; str_length = yyleng; return yytext[0];}
"[" {nb_colonne+=yyleng; str_length = yyleng; return yytext[0];}
"]" {nb_colonne+=yyleng; str_length = yyleng; return yytext[0];}
"." {nb_colonne+=yyleng; str_length = yyleng; return yytext[0];}
[ ] {nb_colonne+=yyleng;}
[\t] {nb_colonne+=4;}
"\n" {nb_ligne++; nb_colonne=1;}

{idf} {if(yyleng<=10) {yylval.chaine=strdup(yytext); str_length = yyleng; nb_colonne+=yyleng; return IDF;} 
else printf("Erreur lexicale {ligne %d; colonne %d} : entite '%s' ; un identifiant ne doit pas depasser 10 caracteres\n", nb_ligne, nb_colonne + 1, yytext);}

. {
	printf("Erreur lexicale {ligne %d ; colonne %d} : entite '%s' non reconnue!\n", nb_ligne, nb_colonne, yytext);
    nb_colonne+=yyleng;
    exit(1);
}
%%

int yywrap(){
	return 1;
}
