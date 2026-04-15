#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <ctype.h>
#define ROTL(x, n) ((x << n) | (x >> (32 - n)))  // Rotation circulaire a gauche

struct NT
{
	char* val;
	char* type;
};

typedef struct element element;
struct element
{
    int used; //preuve de l'utilisation de l'entite dans les instructions or la declaration. A utiliser lors de l'optimisation
	char nom[12]; //la valeur de l'IDF
	int code; //1:classe ; 2:methode ; 3: constructeur ; 4: exception ; 5: variable ; 6: constante
	char location[32]; //vide pour classe; nom_classe pour methode ou constructeur; nom_methode+nom_classe pour attribut d'une methode;
	int signature; //par defaut 1 pour public; 2 (protected); 3 (private); 4 (static); public/private/protected static = 41/ 42 /43
    char type[11]; //par defaut 0 (pas de type); 1 pour entier; 2 pour float; 3 pour double; 4 pour boolean
	int parametre; //pour les methodes et constructeurs
	int nb_ligne; //par defaut c'est 0 pour une var simple ou methode ou classe, mais pas pour un tableau ou matrice
    int nb_col; //pareil que nb_col
	struct element *suiv; //chainage en cas de collision
	struct element *suivParametre; //pour enchainer la methode a ses parametres
};

// declaration de notre table des symboles (table de hachage)
element* TS[2000];

//signature des differentes fonctions
void init();
int hachage(const char chaine [], int table_size);
int rechercher(char nom[], char location[], element ** in);
char* concat(char* nom_methode, char* nom_classe);
void inserer(char nom[], int code, char nom_methode[], char nom_classe[], int signature, char type[], int parametre, int nb_ligne, int nb_col);
int declared(char nom[], char location[]);
int getcode(char nom[], char nom_methode[], char nom_classe[]);
char* getlocation(char nom[], char ch[], char ch1[]);
int getsignature(char nom[], char location[]);
char* gettype(char nom[], char location[]);
char* rechercher_parametre(char* nom_methode, char* nom_classe, int a);
char* max(char* a, char* b);
int getparametre(char nom[], char location[]);
int getNbLigne(char nom[], char location[]);
int getNbCol(char nom[], char location[]);
void used(char nom[], char location[]);
void nb_parametre(char nom[], char location[], int parametre);
void nb_col_ligne(char nom[], char location[], int nb_ligne, int nb_col);
void delete_unused();
void afficher();


