#ifndef QUAD_H_INCLUDED
#define QUAD_H_INCLUDED
#include <string.h>
#include <stdbool.h>
#include <ctype.h>
#include "pile.h"

/*********************************************QUADRUPLETS*********************************************/
//----------------------------------------------------------------------------------------------------------
typedef struct quadruple{
	char operation[100]; //operation (+,-,=,...)
	char operand1[100]; //operand 1
	char operand2[100]; //operand 2
	char result[100]; //result
}quadruple;

quadruple quad[1000];//quad est le nom de la matrice contenant les quadruplets des instructions
int qc;

void insererQuad(char operation[],char operand1[],char operand2[],char result[])
{
	strcpy(quad[qc].operation , operation);
	strcpy(quad[qc].operand1 , operand1);
	strcpy(quad[qc].operand2 , operand2);
	strcpy(quad[qc].result , result);
	qc++;
}

void majQuad(int ligne_quad, int colonne_quad, char val [])
{
    if 		(colonne_quad==0) strcpy(quad[ligne_quad].operation , val);
	else if (colonne_quad==1) strcpy(quad[ligne_quad].operand1 , val);
	else if (colonne_quad==2) strcpy(quad[ligne_quad].operand2 ,val);
	else if (colonne_quad==3) strcpy(quad[ligne_quad].result , val);
}

void majCondQuad(int ligne_quad){
	if(strcmp("BE", quad[ligne_quad-1].operation)==0) {majQuad(ligne_quad-1, 0, "BNE");}
	else if(strcmp("BNE", quad[ligne_quad-1].operation)==0) {majQuad(ligne_quad-1, 0, "BE");}
	else if(strcmp("BG", quad[ligne_quad-1].operation)==0) {majQuad(ligne_quad-1, 0, "BLE");}
	else if(strcmp("BGE", quad[ligne_quad-1].operation)==0) {majQuad(ligne_quad-1, 0, "BL");}
	else if(strcmp("BL", quad[ligne_quad-1].operation)==0) {majQuad(ligne_quad-1, 0, "BGE");}
	else if(strcmp("BLE", quad[ligne_quad-1].operation)==0) {majQuad(ligne_quad-1, 0, "BG");}
}

void afficherQuad()
{
	printf("********************* LesQuadruplets *********************\n");
	int i;
	for(i=0;i<qc;i++)
	{
		printf("\n %d - ( %s , %s , %s , %s)",i,quad[i].operation,quad[i].operand1,quad[i].operand2,quad[i].result);
		printf("\n---------------------------------------------------\n");
	}
}
//----------------------------------------------------------------------------------------------------------

#endif // QUAD_H_INCLUDED

