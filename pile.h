#ifndef PILE_H_INCLUDED
#define PILE_H_INCLUDED

//declaration d'une pile
typedef struct cellule* pile;
struct cellule
{
    int info;
    pile suiv;
};

typedef struct cellule1* pile1;
struct cellule1
{
    char* info;
    pile1 suiv;
};

pile pile_deb_fin_quad_methode;

//CODE des fonctions
pile initPile()
{
    return (NULL);
}

pile1 initPile1()
{
    return (NULL);
}

//----------------------------------------------------------------------------------------------------------------
int pileVide(pile p)
{
    if(p==NULL)
        return 1;
    else return 0;
}

int pileVide1(pile1 p)
{
    if(p==NULL)
        return 1;
    else return 0;
}

//----------------------------------------------------------------------------------------------------------------
int sommetPile(pile p)
{
    return (p->info);
}

char* sommetPile1(pile1 p)
{
    return (p->info);
}

//----------------------------------------------------------------------------------------------------------------
void empiler(pile *p, int x)
{
    pile q;
    q=(pile)malloc(sizeof(struct cellule));
    q->info=x;
    q->suiv=*p;
    *p=q;

}

void empiler1(pile1 *p, char* x)
{
    pile1 q=(pile1)malloc(sizeof(struct cellule1));
    q->info=strdup(x);
    q->suiv=*p;
    *p=q;
}

//----------------------------------------------------------------------------------------------------------------
void desempiler(pile *p, int* x)
{
   pile q;
   *x = (*p)->info;
   q=*p;
   *p=(*p)->suiv;
   free(q);
}

void desempiler1(pile1 *p, char** x)
{
   pile1 q;
   *x=strdup((*p)->info);
   q=*p;
   *p=(*p)->suiv;
   free(q);
}

void afficherPile(pile p){
    while(p!=NULL){
        printf("%d    ", p->info);
        p = p->suiv;
    }
    printf("\n");
}


#endif // PILE_H_INCLUDED
