#include "ts.h"

/****************************** Initialisation de la table de hashage ************************************/
void init () {
	int i;
    for(i=0; i<2000; i++){
		TS[i]=NULL;
	}
}

/******************************** Fonction de hachage basee sur SHA-1 ************************************/
int hachage(const char chaine [], int table_size) {
    // Initialisation des registres de 32bits (inspirees de la celebre fonction de hachage SHA-1)
    uint32_t h0 = 0x67452301; //l'hexadecimale est juste une notation compacte pour representer les 32bits du registre
    uint32_t h1 = 0xEFCDAB89; //67:0110 0111(8bits) , 45:0100 0101(8bits) , 23:0010 0011(8bits) , 01: 0000 0001(8bits)
    uint32_t h2 = 0x98BADCFE;
    /*La notation hexadecimale est facile a lire et a utiliser pour representer les valeurs en binaire.
     Ces valeures sont des derivees de nombres premiers et des proprietes mathematiques. Elles sont ni trop petites ni trop grandes,
     et ont une repartition uniforme des bits 0 et 1, donc avec les operations (XOR, OR, ROTL) les donnees restent bien melangees,
     afin d'obtenir un hashage final unique pour chaque chaine et maximiser la resistance aux collisions
    */

    // Parcours de la cle par blocs de 4 octets (32 bits)
    uint32_t fragment = 0;
    size_t i;
    for (i = 0; i < strlen(chaine); i++) {
        // Construction des blocs 32 bits avec decalage a gauche de 8 bits et operaton OR sur le caractere specifie
        fragment = (fragment << 8) | chaine[i]; //le caractere est converti en binaire avant l'application du OR

        // Toutes les 4 lettres ou si c'est le dernier caractere
        if ((i + 1) % 4 == 0 || i == strlen(chaine) - 1) {
            //Mise a jour des registres avec l'operation circulaire a gauche. Les nombres 5,7,3 sont choisis pour eviter
            //la repetition et avoir une bonne dispertion des bits avec un calcul rapide et efficace afin de minimiser les collisions
            h0 = ROTL(h0, 5) + fragment;//rotation de 5bits
            h1 = ROTL(h1, 7) ^ fragment;//rotation de 7bits
            h2 = (h2 + fragment) ^ ROTL(h2, 3);//operation  XOR (^) et rotation de 3bits (ROTL)

            fragment = 0;  // Reinitialiser pour le prochain bloc
        }
    }

    // Compression finale avec operation XOR (^) sur les 3 registres et division entiere sur la taille de la table
    uint32_t hash = (h0 ^ h1 ^ h2) % table_size;
    return hash;
}

/*************************************** Fonction de recherche *******************************************/
int rechercher(char nom[], char location[], element ** in){
	int i = hachage(nom, 2000); //trouver un indice pour stocker la nouvelle entite

	if(TS[i]!=NULL){ //si notre case est occupee alors soit il y'a une collision, soit notre entite existe deja
        //dans ce cas on parcourt la liste chainee
        element* curr = TS[i];
        element* prev = NULL;
		do {
            //printf("hi\n");
 			if (strcmp(curr->nom, nom)==0 && strcmp(curr->location, location)==0){//cas ou l'entite existe deja, on retourne -1
 			    //pour dire qu'on l'a deja declare et on stocke ses informations dans le pointeur *in
                
                //printf("hello\n");
				*in = curr;
				return -1;
			}
            prev = curr;
            curr = curr->suiv;
		} while(curr!=NULL); //la gestion des collisions se fait par le chainage
        //printf("good by\n");

		//cas ou l'entite n'existe pas
		*in = prev; //on stocke celle-ci dans le prochain pointeur null du poiteur actuel car il s'agit d'une collision: T[i] est occupee
	}
	else *in = NULL; //pas de collision dans ce cas, on stocke notre entite dans T[i] car c'est une case libre
    return i; //on retourne l'indice de la case libre, dans laquelle on va la stocker
}

/**************************************** Fonction d'insertion *******************************************/
void inserer(char nom[], int code, char nom_methode[], char nom_classe[], int signature, char type[], int parametre, int nb_ligne, int nb_col){
    element *p, *q;
    char* location = concat(nom_methode, nom_classe);
	int i = rechercher(nom, location, &q); //on cherche une position libre dans la table
    p = malloc(sizeof(element)); //reserver de l'espace memoire et stocker nos donnees
    p->used = 0;
    strcpy(p->nom, nom);
    p->code = code;
    strcpy(p->location, location);
    p->signature = signature;
    strcpy(p->type, type);
    p->parametre = parametre;
    p->nb_ligne = nb_ligne;
    p->nb_col = nb_col;
    if(q != NULL) q->suiv = p;  //collision,T[i] occupee. Donc on chaine notre poiteur a celui qui le precede
    else TS[i] = p; //T[i] est libre, pas de collisions
    p->suiv = NULL; //notre pointeur n'a pas de suivant

    if(code==5 && parametre!=0){
        element* methode = NULL;
        if(rechercher(nom_methode, nom_classe, &methode)==-1){
            if (methode!=NULL){
                p->suivParametre = methode->suivParametre;
                methode->suivParametre = p;
            }
        }
    }
    else p->suivParametre = NULL;
}

/***************************************** Fonction concatenation ****************************************/
char* concat(char* nom_methode, char* nom_classe){
    int fullSize = strlen(nom_methode) + strlen(nom_classe); // Taille totale
    char *ch2 = (char *) malloc(fullSize + 2);
    strcpy(ch2, nom_methode);
    strcat(ch2, nom_classe);
    return ch2;
}

/************************** Fonction de verification de la declaration d'un idf **************************/
int declared(char nom[], char location[]){
	element *p;
	int i = rechercher(nom, location, &p);
	if(i==-1) return 1; //si i = -1 donc l'entite existe deja dans la table
	else return 0; //sinon elle n'existe pas
}

/************************************** Fonction qui reccupere le code ***********************************/
int getcode(char nom[], char nom_methode[], char nom_classe[]){
	element *p;
    int fullSize = strlen(nom_methode) + strlen(nom_classe); // Taille totale
    char *ch2 = (char *) malloc(fullSize + 1);
    strcpy(ch2, nom_methode);
	int i = rechercher(nom, strcat(ch2, nom_classe), &p); //on recupere le pointeur de notre entite
	return p->code;
}

/********************************** Fonction qui reccupere la signature ***********************************/
int getsignature(char nom[], char location[]){
	element *p;
	int i = rechercher(nom, location, &p); //on recupere le pointeur de notre entite
	return p->signature;
}

/************************************ Fonction qui reccupere le type **************************************/
char* gettype(char nom[], char location[]){
	element *p;
	int i = rechercher(nom, location, &p); 
	return p->type;
}

/************************************ Fonction qui reccupere le type **************************************/
char* rechercher_parametre(char* nom_methode, char* nom_classe, int a){
    element* methode = NULL;
    if (rechercher(nom_methode, nom_classe, &methode) == -1 && methode != NULL){
        methode = methode->suivParametre;
        while(methode != NULL){
            if(methode->parametre == a)
            {
                return methode->type;
            }
            methode = methode->suivParametre;
        }
        return NULL;
    }
}

/********************************** Fonction max pour comparaison entre types *****************************/
char* max(char* a, char* b){
	if(strlen(a)>strlen(b)) return a;
	return b;
}

/********************************** Fonction qui reccupere le nb parametre ********************************/
int getparametre(char nom[], char location[]){
	element *p;
	int i = rechercher(nom, location, &p); 
	return p->parametre;
}

/*********************************** Fonction qui reccupere le nb_ligne **********************************/
int getNbLigne(char nom[], char location[]){
	element *p;
	int i = rechercher(nom, location, &p); 
	return p->nb_ligne;
}

/************************************ Fonction qui reccupere le nb_col ************************************/
int getNbCol(char nom[], char location[]){
	element *p;
	int i = rechercher(nom, location, &p); 
	return p->nb_col;
}

/**************************************** Variable declaree utilisee *************************************/
void used(char nom[], char location[]){
	element *q;
	int i = rechercher(nom, location, &q);
	if(q!=NULL) q->used=1; // si on a utiliser notre entite dans une affectation alors on doit le marquer
}

/******************************************* Ajuster le nbr_parametre ************************************/
void nb_parametre(char nom[], char location[], int parametre){
	element *q;
	int i = rechercher(nom, location, &q);
	if(q!=NULL){q->parametre = parametre;}
}

/*************************************** Ajuster le nbr_ligne et nbr_col **********************************/
void nb_col_ligne(char nom[], char location[], int nb_ligne, int nb_col){
	element *q;
	int i = rechercher(nom, location, &q);
	if(q!=NULL){q->nb_ligne = nb_ligne; q->nb_col = nb_col;} 
}

/************************* optimisation: suppression variable declaree non utilisee **********************/
void delete_unused(){
    int i;
    for (i = 0; i < 2000; i++) {
        element* curr = TS[i];
        element* prev = NULL;

        while (curr != NULL) {
            if (curr->used == 0) { // Si l'element doit être supprime
                element *temp = curr;
                curr = curr->suiv; // Avancer dans la liste, avant de supprimer

                if (prev == NULL) {TS[i] = curr;}  // Suppression en debut de liste
                else {prev->suiv = curr;}  // Suppression en milieu ou fin de liste

                free(temp); // Liberer la memoire
            } else {
                prev = curr; // Avancer seulement si pas supprime
                curr = curr->suiv;
            }
        }
    }
}

/******************************************* Fonction d'affichage ****************************************/
void afficher(){
	element *p;
    printf("\n***********************************************************************************************************************************************\n");
    printf("*                                                              Table des symboles  IDF                                                        *\n");
    printf("***********************************************************************************************************************************************\n");
    printf("_______________________________________________________________________________________________________________________________________________\n");
    printf("|statut    |Nom             |Code         |location                |Signature     | Type            |Nb_parametre   |Nb_ligne     |Nb_col      |\n");
    printf("|__________|________________|_____________|________________________|______________|_________________|_______________|_____________|____________|\n");

    int i=0;
    while(i<2000){
        p=TS[i];
        while(p!=NULL){
            printf("|%9d |%15s |%12d |%23s | %12d | %16s| %13d | %11d | %10d |\n", p->used,p->nom, p->code, p->location, p->signature, p->type, p->parametre, p->nb_ligne, p->nb_col);
            printf("|__________|________________|_____________|________________________|______________|_________________|_______________|_____________|____________|\n");
            p=p->suiv;
        }
        i++;
    }

}

/*
void afficher_parametres(element* methode){
    printf("methode : %s\n", methode->nom);
    element* parametre = methode->suivParametre;
    while(parametre !=NULL){
        printf("-> Param_%d : %s, type: %s\n", parametre->parametre, parametre->nom, parametre->type);
        parametre = parametre->suivParametre;
    }
}
*/

