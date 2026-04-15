#ifndef OPTIMISATION_H_INCLUDED
#define OPTIMISATION_H_INCLUDED
#include "quad.h"

extern quadruple quad[1000];//quad est le nom de la matrice contenant les quadruplets
extern int qc;

typedef struct {
	int num_quad;
	int niveau;
} Niveau_quad;

Niveau_quad tab_niv_quad[1000];
int ind_niv = 0;
int niv_imbrication = 0;


/*
*	Fonctions elementaires
*/
/*==== START ====*/

//verifier si une chaine de caracteres est un temporaire
int estTemporaire(const char *x) {
    if (x[0] != 't') return 0;
    if (x[1] == '\0') return 0; // pas de chiffre apres le 't'
    int i;
	for (i = 1; x[i] != '\0'; i++) {
        if (!isdigit(x[i])) return 0;
    }
    return 1;
}

// Retourne l'indice du temporaire tX => X (ex: "t2" -> 2)
int getTempIndex(const char *s) {
    if (s[0] == 't') {
        return atoi(s + 1);
    }
    return -1;
}

// Decremente le numero du temporaire dans une chaine "tX" -> "t(X-1)"
void decrementTemp(char *s, int nbr) {
    int index = getTempIndex(s);
    if (index > 0) {
        char newTemp[100];
        sprintf(newTemp, "t%d", index - nbr);
        strcpy(s, newTemp);
    }
}

// Remplace un temporaire par un autre si egal a "ancien"
void remplacerTemp(char *s, const char *ancien, const char *nouveau) {
    if (strcmp(s, ancien) == 0) {
        strcpy(s, nouveau);
    }
}

void mettreAJourTemporaires(const char *nouveauTemp, int quadASauter, int nbr, int verif) {
	if(verif>-1){
        char* fields[] = {quad[verif].operand1, quad[verif].operand2};
		int j;
        for (j = 0; j < 2; j++) {
            if (strcmp(quad[quadASauter].result, fields[j])==0) {
            	strcpy(fields[j], quad[quadASauter].operand1);
            } 
        }
	}
	else{
		int i, s, n = quadASauter-nbr+1;
		const char* tempASupprimer = quad[quadASauter].result;
    	int numASupprimer = getTempIndex(tempASupprimer);
		for(s = n; s <= quadASauter; s++){
			const char* tempASupprimer = quad[s].result;
    		int numASupprimer = getTempIndex(tempASupprimer);
			for (i = 0; i < qc; i++) {
				if (i == s) continue;
        		char* fields[] = {quad[i].operand1, quad[i].operand2, quad[i].result};
				int j;
        		for (j = 0; j < 3; j++) {
            		int idx = getTempIndex(fields[j]);
            		if (idx == numASupprimer) {
                		remplacerTemp(fields[j], tempASupprimer, nouveauTemp);
            		} else if (idx > numASupprimer) {
                		decrementTemp(fields[j], 1);
            		}
        		}
    		}
		}
	}
}

void mettreAJourBranchements(int numQuadSupprime, int nbr) {
	int i;
    for (i = 0; i < qc; i++) {
        if (quad[i].operation[0] == 'B' || quad[i].operation[0] == 'Z') {
            int ligne = atoi(quad[i].operand1);
            if (ligne > numQuadSupprime) {
                char updated[100];
                sprintf(updated, "%d", ligne - nbr);
                strcpy(quad[i].operand1, updated);
            }
        }
    }
}

void supprimer_quad_temp(int num, const char *tempRemplacement, int nbr, int verif) {
    // etape 1 : Mise a jour des temporaires
	if(verif!=-2){mettreAJourTemporaires(tempRemplacement, num, nbr, verif);}

    // etape 2 : Mise a jour des branchements
    mettreAJourBranchements(num, nbr);

    // etape 3 : Suppression en decalant
	int i;
    for (i = num + 1; i < qc; i++) {
        quad[i-nbr] = quad[i];
    }
    qc = qc-nbr;
}

//supprimer le dernier quad BR 
void supprimer_quad(int numqd)
{
	int i = numqd;
	while (i < qc)
	{
		quad[i] = quad[i+1];
		i++;
	}
	qc--;
	i=0;
	while(i<qc)
	{		
		if(quad[i].operation[0] == 'B')
		{			
			int jumpAdr = atoi(quad[i].operand1);
			if(jumpAdr > numqd)
			{
				jumpAdr--;
				sprintf(quad[i].operand1,"%d",jumpAdr);
			}
		}
		i++;	
	}
}


//trouver le debut et la fin d'une suite de quads successifs qui ont la meme operation que celle donnee en parametres 
//dans le perimetre d'un quad dont le numero est aussi donne en parametres
void trouverBlocOperation(int num, const char *op, int *debut, int *fin) {
    int i;

    // Cherche vers l'arriere
    i = num;
    while (i >= 0 && strcmp(quad[i].operation, op) == 0) {
        i--;
    }
    *debut = i + 1;

    // Cherche vers l'avant
    i = num;
    while (i < qc && strcmp(quad[i].operation, op) == 0) {
        i++;
    }
    *fin = i - 1;
}

/*
*	supprimer les  BR qui branche vers le quad juste qui suit
**/
void majQuadBR(int ligne_quad, int colonne_quad, char val [])
{
	int num_quad_br = atoi(val);
	
	if(num_quad_br==ligne_quad+1) supprimer_quad(ligne_quad);
    else
    {
    	if 		(colonne_quad==0) strcpy(quad[ligne_quad].operation , val);
		else if (colonne_quad==1) strcpy(quad[ligne_quad].operand1 , val);
		else if (colonne_quad==2) strcpy(quad[ligne_quad].operand2 ,val);
		else if (colonne_quad==3) strcpy(quad[ligne_quad].result , val);
    }
}

// Recherche si un element resultat d'un quad de numero num_quad apparait comme operande (1 ou 2) dans les quad qui suivent

int resultat_utilise_comme_operande(int num_quad)
{
	int i, a, nbr=0;
	for(i=num_quad+1; i<qc; i++)
	{
		if((strcmp(quad[num_quad].result,quad[i].operand1)==0 && !strcmp(quad[num_quad].result,quad[i].operand2)==0)
			|| (!strcmp(quad[num_quad].result,quad[i].operand1)==0 && strcmp(quad[num_quad].result,quad[i].operand2)==0)
		)
		{nbr++; a = i;}	
	}
	if(nbr==1){return a;}
	return -1;
}


/*
* Verifier si le resultat ou l'un des operandes d'un quad dont le numero est num_quad1 
* a ete modifie entre num_quad1 et un autre quad de num_quad2
*
* @param pos_op indique si la verification se fait pour l'operande 1 ou 2
**/
int modifie_entre(int num_quad1,int num_quad2,int pos_op)
{	
	int i;
	for(i=num_quad1+1;i<num_quad2;i++)
	{
		if(pos_op ==1) //on cherche si quad[num_quad1].operand1 apparait comme resultat dans un quad en bas entre num_quad1 et num_quad2
		{
			if(strcmp(quad [i].result,quad[num_quad1].operand1)==0)
				return 1;
		}
		if(pos_op ==2) //on cherche si quad[num_quad1].operand2 apparait comme resultat dans un quad en bas entre num_quad1 et num_quad2
		{
			if(strcmp(quad [i].result,quad[num_quad1].operand2)==0)
				return 1;
		}
		if(pos_op ==3) //on cherche si quad[num_quad1].result apparait comme resultat dans un quad en bas entre num_quad1 et num_quad2
		{
			if(strcmp(quad [i].result,quad[num_quad1].result)==0)
				return 1;
		}
	}
	return 0;
}

//pour detecter si un BR est present entre deux quad pour ne pas faire optimisation entre deux quad de 2 if de meme niveau
int BR_entre(int num_quad1,int num_quad2)
{
	int i=0;
	for(i=num_quad1+1;i<num_quad2;i++)
	{
		if(quad[i].operation[0]=='B') return 1;
	}
	
	return 0;
}


void remplacer(int num_quad1, int num_quad2)
{
	if(!strcmp(quad[num_quad1].result,quad[num_quad2].operand1) )
	{
		strcpy(quad[num_quad2].operand1, quad[num_quad1].operand1);
	}
	else
	{
		if(!strcmp(quad[num_quad1].result,quad[num_quad2].operand2))
		{
				strcpy(quad[num_quad2].operand2, quad[num_quad1].operand1);
		}
	}
}


/*==== END ====*/



//-----------------------------------------------------------------------

/*
*	Simplification algebrique
*/
/*==== START ====*/
void simplifier_mult(int i)
{
	//cas 1: (*, 1, E, X) ==> E peut etre une Cst, un temporaire ou une variable; X peut etre une variable ou un temporaire
	if(strcmp(quad[i].operation,"*")==0 && strcmp( quad[i].operand1, "1")==0)
	{
		supprimer_quad_temp(i, quad[i].operand2, 1, -1);	
	}
	//cas 2: (*, E, 1, X) ==> E peut etre une Cst, un temporaire ou une variable; X peut etre une variable ou un temporaire
	if(strcmp(quad[i].operation,"*")==0 && strcmp( quad[i].operand2, "1")==0)
	{
		supprimer_quad_temp(i, quad[i].operand1, 1, -1);
	}
	
	//cas 3: (*, 2, E, X) ==> E peut etre une Cst, un temporaire ou une variable; X peut etre une variable ou un temporaire
	if(strcmp(quad[i].operation,"*")==0 && strcmp( quad[i].operand1, "2")==0)
	{
		strcpy(quad[i].operation,"+");
		strcpy(quad[i].operand1,quad[i].operand2);
	}
	//cas 4: (*, E, 2, X) ==> E peut etre une Cst, un temporaire ou une variable; X peut etre une variable ou un temporaire
	if(strcmp(quad[i].operation,"*")==0 && strcmp( quad[i].operand2, "2")==0)
	{
		strcpy(quad[i].operation,"+");
		strcpy(quad[i].operand2,quad[i].operand1);
	}
}

void simplifier_div_mult(int i)
{
	int debut, fin;
	//cas 0 : simplification des multiplications du genre x*...*0
	if(strcmp(quad[i].operation,"*")==0 && (strcmp(quad[i].operand1, "0")==0 || strcmp( quad[i].operand2, "0")==0))
	{
		trouverBlocOperation(i, "*", &debut, &fin);
		int n = fin - debut + 1;
		strcpy(quad[fin].operand1,"0");
		if(strcmp(quad[debut-1].operation,"/")==0){strcpy(quad[debut-1].operand1,"0");}
		supprimer_quad_temp(fin, quad[fin].operand1, n, -1);
	}

	//cas 0 : simplification des divisions du genre 0/..../x
	if(strcmp(quad[i].operation,"/")==0 && strcmp( quad[i].operand1, "0")==0)
	{
		trouverBlocOperation(i, "/", &debut, &fin);
		int n = fin - debut + 1;
		strcpy(quad[fin].operand1,"0");
		if(strcmp(quad[debut-1].operation,"*")==0){strcpy(quad[debut-1].operand1,"0");}
		supprimer_quad_temp(fin, quad[fin].operand1, n, -1);
	}
}

void simplifier_plus_mois(int i)
{
	
	//cas1: 1.(+, j, 1, t1)
	//      2.(-, t1, 1, t2)
	//      3. ......
	if(strcmp(quad[i].operation,"+")==0 && strcmp( quad[i].operand2, "1")==0){
		if(strcmp(quad[i+1].operation,"-")==0 && strcmp( quad[i].operand2, "1")==0){
			supprimer_quad_temp(i+1, quad[i+1].operand1, 1, -1);
			supprimer_quad_temp(i, quad[i].operand1, 1, -1);
		}
	}

	//cas1: 1.(+, 1, j, t1)  ==> celui-ci est quad[i]
	//      2.(-, t1, 1, t2) ==> celui-ci est quad[i+1]
	//      3. ......
	if(strcmp(quad[i].operation,"+")==0 && strcmp( quad[i].operand1, "1")==0){
		if(strcmp(quad[i+1].operation,"-")==0 && strcmp( quad[i].operand2, "1")==0){
			supprimer_quad_temp(i+1, quad[i+1].operand1, 1, -1);
			supprimer_quad_temp(i, quad[i].operand2, 1, -1);
		}
	}

	//cas2: 1.(-, j, 1, t1)  ==> celui-ci est quad[i]
	//      2.(+, t1, 1, t2) ==> celui-ci est quad[i+1]
	//      3. ......
	if(strcmp(quad[i].operation,"-")==0 && strcmp( quad[i].operand2, "1")==0){
		if(strcmp(quad[i+1].operation,"+")==0 && strcmp( quad[i].operand2, "1")==0){
			supprimer_quad_temp(i+1, quad[i+1].operand1, 1, -1);
			supprimer_quad_temp(i, quad[i].operand1, 1, -1);
		}
	}

	//cas3: 1.(-, j, 0, t1) ou bien   1.(+, j, 0, t1) ==> celui-ci est quad[i]
	if(	   (strcmp(quad[i].operation,"+")==0 && strcmp( quad[i].operand2, "0")==0)
		|| (strcmp(quad[i].operation,"-")==0 && strcmp( quad[i].operand2, "0")==0)
	){
		supprimer_quad_temp(i, quad[i].operand1, 1, -1);
	}

	if(strcmp(quad[i].operation,"+")==0 && strcmp( quad[i].operand1, "0")==0){
		supprimer_quad_temp(i, quad[i].operand2, 1, -1);
	}
}

void simplifier_plus(int i)
{
	int j=0;
		if(strcmp(quad[i].operation,"+")==0 && strcmp( quad[i].operand1, "1")==0)
		{
			//cas: 1.(+, 1, j, t1)  ==> celui-ci est quad[i]
			//	   2.(=, t1, , X)  ==> dans la condition qui suit, on a fait quad[i+1] car on doit rechercher X dans les prochains quads et pas t1
			// ...
			//	   9.(-, X, 1, t6)  ==> a  ce niveau apparait 1+j-1, ce quad devient (=, t1, , t6) qu'on va propager en copie vers le quad 10 et on supprime le 9 car code inutile
			//	   10.(=, t6, , Y)..==> apres elimination du code inutile on aura ici (=, X, , Y)
			for(j=i+1;j<qc;j++)
			{
				if(strcmp(quad[j].operation,"-")==0 && strcmp( quad[i+1].result, quad[j].operand1)==0 && strcmp( quad[j].operand2, "1")==0)
				{ 
					if(	   !modifie_entre(i,j,2) 
						&& !modifie_entre(i,j,3) 
						&& !modifie_entre(i+1,j,3)
						&& tab_niv_quad[i].niveau <= tab_niv_quad[j].niveau
						&& !BR_entre(i, j)
					  )
					{
						strcpy(quad[j].operation,"=");
						strcpy(quad[j].operand1,quad[i].operand2);
						strcpy(quad[j].operand2,"");
					}
				}
			}
		}

		if(strcmp(quad[i].operation,"+")==0 && strcmp( quad[i].operand2, "1")==0)
		{
			//cas: 1.(+, j, 1, t1)  ==> celui-ci est quad[i]
			//	   2.(=, t1, , X)  ==> dans la condition qui suit, on a fait quad[i+1] car on doit rechercher X dans les prochains quads et pas t1
			// ...
			//	   9.(-, X, 1, t6)  ==> a  ce niveau apparait j+1-1, ce quad devient (=, t1, , t6) qu'on va propager en copie vers le quad 10 et on supprime le 9 car code inutile
			//	   10.(=, t6, , Y)..==> apres elimination du code inutile on aura ici (=, X, , Y)
			for(j=i+1;j<qc;j++)
			{ 
				if(strcmp(quad[j].operation,"-")==0 && strcmp( quad[i+1].result, quad[j].operand1)==0 && strcmp( quad[j].operand2, "1")==0)
				{ 
					if(    !modifie_entre(i,j,1) 
						&& !modifie_entre(i,j,3) 
						&& !modifie_entre(i+1,j,3)
						&& tab_niv_quad[i].niveau <= tab_niv_quad[j].niveau
						&& !BR_entre(i, j)
					  )
					{
						strcpy(quad[j].operation,"=");
						strcpy(quad[j].operand1,quad[i].operand1);
						strcpy(quad[j].operand2,"");
					}
				}	
			}	
		}
}

void simplification_algebrique()
{
	int i = 0, j=0;
	for (i = 0; i < qc; i++){simplifier_div_mult(i);}
	for (i = 0; i < qc; i++){simplifier_mult(i);}
	for (i = 0; i < qc; i++){simplifier_plus_mois(i);}
	for (i = 0; i < qc; i++){simplifier_plus(i);}
}

/*==== END ====*/


//-----------------------------------------------------------------------


/*
*	Propagation des constantes
*/
/*==== START ====*/


bool verif_affect_const(int i) {
    // Verifie que c est une affectation simple (=) et que l operande 1 est une constante numerique
    return strcmp(quad[i].operation, "=") == 0 &&
           isdigit(quad[i].operand1[0]) && // commence par un chiffre (constante entiere)
           strlen(quad[i].operand2) == 0; // pas de deuxieme operande
}

int prochaine_modif(int debut, const char *var) {
    int j;
	for (j = debut; j < qc; j++) {
        if (strcmp(quad[j].result, var) == 0) // Si la variable est modifiee
            return j; // On retourne sa position
    }
    return -1; // Elle n est jamais modifiee apres
}

int propager_const(int debut, int fin, const char *var, const char *constante) {
    int utilisation = 0;
    int limite = (fin == -1) ? qc : fin; // Si pas de modification, on va jusqu'a la fin
	int j;
    for (j = debut; j < limite; j++) {
        if (strcmp(quad[j].operand1, var) == 0) {
            strcpy(quad[j].operand1, constante); // Remplacer operande 1 par la constante
            utilisation++; // On compte l'utilisation
        }
        if (strcmp(quad[j].operand2, var) == 0) {
            strcpy(quad[j].operand2, constante); // Remplacer operande 2 par la constante
            utilisation++;
        }
    }
    return utilisation; // Nombre de fois que la variable a ete utilisee et remplacee
}

bool verif_utilisation_avant_modif(int debut, int modifPos, const char *var) {
    if (modifPos == -1) return true; // Si jamais modifiee, c'est sur que tout est avant
	int j;
    for (j = modifPos + 1; j < qc; j++) {
        // Si la variable est encore utilisee apres sa modification
        if (strcmp(quad[j].operand1, var) == 0 || strcmp(quad[j].operand2, var) == 0)
            return false;
    }
    return true; // Sinon, toutes les utilisations sont bien avant la modification
} 

void propagation_constante(){
    int i;
	for (i = 0; i < qc; i++) { // On parcourt tous les quadruples
        if (verif_affect_const(i)) { // Si c'est une affectation d'une constante, ex: b = 5
            char constante[100];
            strcpy(constante, quad[i].operand1); // On stocke la constante
            char var[100];
            strcpy(var, quad[i].result); // Et la variable affectee (ex: b)

            int utilisation = 0;
            // On cherche a partir de l'instruction suivante si la variable est modifiee
            int posModif = prochaine_modif(i + 1, var);

            // On propage la constante jusqu a sa prochaine modification (ou jusqu a la fin)
            utilisation = propager_const(i + 1, posModif, var, constante);

            // Si la variable n est plus utilisee ou seulement utilisee avant d etre modifiee
            if (utilisation == 0 || (utilisation > 0 && verif_utilisation_avant_modif(i + 1, posModif, var))) {
                supprimer_quad_temp(i, quad[i].result, 1, -1); // On supprime le quad initial d'affectation inutile
                i--; // On ajuste i car les quads ont ete decales apres suppression
            }
        }
    }
}

/*==== END ====*/



//-----------------------------------------------------------------------


/*
*	Propagation de copies
*/
/*==== START ====*/

void propagation_copie()
{
	int i;
	int ind_utilisation;
	for(i=0;i<qc;i++)
	{	if(strcmp(quad[i].operation,"=")==0 && !estTemporaire(quad[i].operand1) && !isdigit(quad[i].operand1[0]) && !estTemporaire(quad[i].result) && !isdigit(quad[i].result[0]))
		{
			ind_utilisation=resultat_utilise_comme_operande(i);
			if(ind_utilisation!=-1)
			{	if(	   !modifie_entre(i,ind_utilisation,1)
					&& !modifie_entre(i,ind_utilisation,3)
					&& tab_niv_quad[i].niveau <= tab_niv_quad[ind_utilisation].niveau
					&& !BR_entre(i, ind_utilisation))
				{
					remplacer(i,ind_utilisation);
				}
			}
		}
	}
}

/*==== END ====*/


//-----------------------------------------------------------------------

/*
*	Propagation d'expression
*/
/*==== START ====*/

void propagation_expression()
{
	int i;
	int ind_utilisation;
	
	for(i=0;i<qc;i++)
	{	if(strcmp(quad[i].operation,"=")==0 && (quad[i].operand1[0] < 'A' || quad[i].operand1[0] > 'Z') && !estTemporaire(quad[i].result) && !isdigit(quad[i].result[0]))
		{
			ind_utilisation=resultat_utilise_comme_operande(i);
			
			if(ind_utilisation!=-1)
			{	
				if(    !modifie_entre(i,ind_utilisation,1) 
					&& !modifie_entre(i,ind_utilisation,3)
					&& tab_niv_quad[i].niveau <= tab_niv_quad[ind_utilisation].niveau 
					&& !BR_entre(i, ind_utilisation))//il faut tester aussi s'il n'y a pas de BR entre eux
				{
					supprimer_quad_temp(i, quad[i].operand1, 1, ind_utilisation);	
				}
			}
		}
	}
}

/*==== END ====*/


//-----------------------------------------------------------------------

/*
*	Elimination des expressions redondantes
*/
/*==== START ====*/

int modifie_entre2(int debut, int fin, const char* variable) {
    int i;
	for (i = debut + 1; i < fin; i++) {
        if (strcmp(quad[i].result, variable) == 0)
            return 1;
    }
    return 0;
}

int sont_expressions_identiques(int i, int j) {
    if (strcmp(quad[i].operation, quad[j].operation) != 0)
        return 0;

    int commutatif = (strcmp(quad[i].operation, "+") == 0) || (strcmp(quad[i].operation, "*") == 0);

    if ((strcmp(quad[i].operand1, quad[j].operand1) == 0 && strcmp(quad[i].operand2, quad[j].operand2) == 0) ||
        (commutatif && strcmp(quad[i].operand1, quad[j].operand2) == 0 && strcmp(quad[i].operand2, quad[j].operand1) == 0))
        return 1;

    return 0;
}

void remplacer_temp_par_expression(const char* ancien, const char* nouveau, int debut) {
    int i;
	for (i = debut; i < qc; i++) {
        if (strcmp(quad[i].operand1, ancien) == 0)
            strcpy(quad[i].operand1, nouveau);
        if (strcmp(quad[i].operand2, ancien) == 0)
            strcpy(quad[i].operand2, nouveau);
    }
}

void elimin_exp_redond(){
    int i;
	for (i = 0; i < qc; i++) {
        if (strcmp(quad[i].operation, "+") == 0 || strcmp(quad[i].operation, "-") == 0 ||
            strcmp(quad[i].operation, "*") == 0 || strcmp(quad[i].operation, "/") == 0) {
			int j;
            for (j = i + 1; j < qc; j++) {
                if (sont_expressions_identiques(i, j)) {
                    if (!modifie_entre2(i, j, quad[i].operand1) &&
                        !modifie_entre2(i, j, quad[i].operand2)) {

                        remplacer_temp_par_expression(quad[j].result, quad[i].result, j + 1);
                        supprimer_quad_temp(j, "", 1, -1);
                        j--;
                    }
                }
            }
        }
    }
}

/*==== END ====*/

//-----------------------------------------------------------------------


/*
* Elimination du code inutile
* On supprime tous les quad dont les temporaires apparaissant dans la pertie resultat
  ne sont plus utilses comme operande ou resultat
*/
/*==== START ====*/

// Verifie si une chaine est utilisee comme operande dans les quads apres un index donne
bool est_utilisee_apres(int index, const char* variable) {
    int i;
	for (i = index + 1; i < qc; i++) {
        if (strcmp(quad[i].operand1, variable) == 0 ||
            strcmp(quad[i].operand2, variable) == 0) {
            return true;
        }
        // Dans les quads de branchement
        if ((quad[i].operation[0] == 'B' || quad[i].operation[0] == 'Z') &&
            strcmp(quad[i].operand1, variable) == 0) {
            return true;
        }
    }
    return false;
}

// Fonction principale d elimination du code mort
void eliminer_code_mort() {
    int i;
	for (i = 0; i < qc; i++) {
        // Si c est un quad dont le resultat est stocke
        if (strlen(quad[i].result) > 0) {
            // Si ce resultat n est jamais utilise par la suite
            if (!est_utilisee_apres(i, quad[i].result)) {
                // Attention : on ne supprime pas les affectations vers des variables finales
                // Exemple : (=, t4, , A) — on garde car A est une vraie variable
                if (quad[i].operation[0] == '=' && !isdigit(quad[i].result[0])) {
                    continue;
                }

                // Supprimer le quad inutile
                supprimer_quad_temp(i, "", 1, -1);

                i--; // Revenir pour traiter le quad suivant apres suppression
            }
        }
    }
} 

/*==== END ====*/

//-----------------------------------------------------------------------


/*
*	Boucle globale de l'optimisation
*/
/*==== START ====*/

int optimisation()
{	
	elimin_exp_redond();
	simplification_algebrique();
	propagation_copie();
	propagation_expression();
	propagation_constante();
	eliminer_code_mort();
	
}

/*==== END ====*/

#endif







