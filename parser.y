%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "ts.c"
#include "optimisation.h"
#define DEBUG 1

extern int yylex();
extern int yyparse();
extern FILE *yyin;

extern int nb_ligne;
extern int nb_colonne;
extern int str_length;

int dans_if=0, sauvPriv = 1, final = 0, nb_argument = 0, nb_tab_col = 0, nb_tab_ligne = 0, nb_return = 0, num = 0, num1=0, verif = 1, nb, for1=0, initialise=1, contr_verif=1;
char* nom_methode = "", *nom_classe = "", *sauvType = "", *sauvType1 = "", *nom, *ch, *type_para, *typexp;

extern pile pile_deb_fin_quad_methode;
pile pile_br_bin;//pour sauvegarder les adresses de branchements des BR binaires
pile pile_br_un; //stocker les num des BR unaires
pile pile_br_bin_or; //stocker les num des BR binaires du OR
pile pile_br_bin_and; //stocker les num des BR binaires du AND
pile pile_deb_quad; //stocker les num des quad du debut des conditions des boucles

pile exp_for; //stocker la valeur de for1 qui exprime quelle variante du for on utilise 

pile1 exp_switch; //stocker les expressions a evaluer dans le switch 
pile1 exp_switch_type;
pile quad_br_bin_switch; //stocker les num des BR binaires du switch
pile pile_br_un_switch; //stocker les num des BR unaires du switch

char tmp[10];//stocker les temporaires
int compteur=1;//indice d'incrementation des temporaires: commence par 1 ==> voir generation du code objet

void yyerror(const char *s);

%}

%union {
    char *chaine;
    int stncnl;
    struct NT  element;
}

%type<stncnl>privacy_opt
%type<stncnl>privacy
%type<stncnl>privacy1
%type<chaine>type
%type<chaine>declaration_var
%type<chaine>liste_v
%type<chaine>liste_c
%type<chaine>corp
%type<stncnl>argmts
%type<stncnl>B
%type<chaine>ID
%type<stncnl>liste_argument
%type<stncnl>arguments
%type<stncnl>liste_parametre
%type<stncnl>parametres
%type<stncnl>parametre
%type<element>appel_methode
%type<chaine>liste_d
%type<chaine>inst_aff
%type<chaine>dec
%type<chaine>dec1
%type<chaine>clause
%type<chaine>inst_for
%type<chaine>dec_for
   
%type<chaine>signe
%type<element>expL
%type<element>exp
%type<element>valeur
%type<element>valeur1
%type<element>left_value


%token <stncnl>PUBLIC <stncnl>PRIVATE <stncnl>PROTECTED <stncnl>STATIC <chaine>ABSTRACT <chaine>VOID <chaine>CLASS <chaine>THIS <chaine>NEW <chaine>FINAL <chaine>INT <chaine>FLOAT <chaine>DOUBLE <chaine>CHAR <chaine>STRING <chaine>BOOLEAN <chaine>IF <chaine>ELSE <chaine>FOR <chaine>DO <chaine>WHILE <chaine>SWITCH <chaine>CASE <chaine>BREAK <chaine>DEFAULT <chaine>RETURN <chaine>TRY <chaine>CATCH <chaine>FINALLY <chaine>THROW
%token <chaine>PRINT <chaine>SETTER <chaine>GETTER <chaine>IDF <chaine>ENTIER <chaine>REEL_F <chaine>REEL_D <chaine>CAR <chaine>STR <chaine>BOOL
%token ADDADD SUBSUB ADD SUB MUL DIV DIVE AND OR NOT BG BL BGE BLE BE BNE
%token ';' ',' ':' '{' '}' '(' ')' '[' ']' '.' '=' ADDEGAL

%left OR
%left AND
%left BG BL BGE BLE BE BNE
%left ADDADD ADD SUB
%left MUL DIV DIVE
%right NOT
%nonassoc IF
%nonassoc ELSE

%start S
%%

S: class_decl {printf("\nProgramme syntaxiquement correcte. \n"); YYACCEPT;}
;

/*============================================ declaration de la classe =====================================*/
class_decl : dec '{' class_body '}' {sauvPriv=1;} class_decl
           | dec '{' class_body '}' {sauvPriv=1;}
;

dec : privacy_opt CLASS IDF  {nom_classe = $3; if(declared($3, "")==1){printf("Erreur semantique a la ligne: %d, double declaration de la classe '%s'\n", nb_ligne, $3);} else{inserer($3, 1, "", "", $1, "", 0, 0, 0);}}; 

privacy_opt: PUBLIC     {$$ = 1; sauvPriv=1;}
           | ABSTRACT   {$$ = 5; sauvPriv=5;}
           | FINAL      {$$ = 6; sauvPriv=6;}
           |            {$$ = 1; sauvPriv=1;}
;

privacy : STATIC            {$$ = 4; sauvPriv=4;}
        | PUBLIC STATIC     {$$ = 41; sauvPriv=41;}
        | PRIVATE STATIC    {$$ = 42; sauvPriv=42;}
        | PROTECTED STATIC  {$$ = 43; sauvPriv=43;}
;

privacy1 : PUBLIC     {$$ = 1; sauvPriv=1;}
         | PRIVATE    {$$ = 2; sauvPriv=2;}
         | PROTECTED  {$$ = 3; sauvPriv=3;}
;


/*================================================= Corp de la classe =======================================*/
class_body : decl_attribut class_body
           | decl_constructor_methode class_body 
           |
;

decl_attribut : privacy declaration_var ';'    
              | privacy declaration_const ';'  
              | privacy declaration_tab ';'        
              | privacy declaration_mat ';'    
              | privacy instanciation ';'      
              | privacy1 declaration_var ';'   
              | privacy1 declaration_const ';'  
              | privacy1 declaration_tab ';'         
              | privacy1 declaration_mat ';'  
              | privacy1 instanciation ';'   
              | declaration_var ';'     
              | declaration_const ';'          
              | declaration_tab ';'            
              | declaration_mat ';'           
              | instanciation ';' 
;

/*=============== declaration variables ===========*/
declaration_var : type liste_v  {$$=$2; initialise=0;}
                | type liste_c  {$$=$2; initialise=1;}
;

type : INT     {$$ = $1; sauvType=$1;}
     | FLOAT   {$$ = $1; sauvType=$1;}
     | DOUBLE  {$$ = $1; sauvType=$1;}
     | CHAR    {$$ = $1; sauvType=$1;}
     | STRING  {$$ = $1; sauvType=$1;}
     | BOOLEAN {$$ = $1; sauvType=$1;}
;

liste_v : IDF ',' liste_v  {$$=$1; if(declared($1, concat(nom_methode, nom_classe))==1){printf("Erreur semantique a la ligne: %d, double declaration de l'attribut '%s'\n", nb_ligne, $1);} else{inserer($1, 5, nom_methode, nom_classe, sauvPriv, sauvType, 0, 0, 0);}; sauvPriv=1;}
		  | IDF              {$$=$1; if(declared($1, concat(nom_methode, nom_classe))==1){printf("Erreur semantique a la ligne: %d, double declaration de l'attribut '%s'\n", nb_ligne, $1);} else{inserer($1, 5, nom_methode, nom_classe, sauvPriv, sauvType, 0, 0, 0);}; sauvPriv=1;}
;

liste_c : IDF '=' exp  ',' liste_c  {  $$=$1;
                                       if(declared($1, concat(nom_methode, nom_classe))==1){printf("Erreur semantique a la ligne: %d, double declaration de l'attribut '%s'\n", nb_ligne, $1);} 
                                       else if(strcmp(sauvType, $3.type)!=0){printf("Erreur semantique a la ligne: %d, incompatibilite de type, affectation %s de type %s ---> '%s' de type %s\n", nb_ligne, $3.val, $3.type, $1, sauvType);}
                                       else{
                                          inserer($1, final+5, nom_methode, nom_classe, sauvPriv, sauvType, 0, 0, 0);
                                    
										            insererQuad("=", $3.val, "", $1);

										            tab_niv_quad[ind_niv].num_quad = qc-1;
										            tab_niv_quad[ind_niv].niveau = niv_imbrication;
										            ind_niv++;
                                       };
                                       sauvPriv=1; final = 0;
                                    }

        | IDF '=' exp               {  $$=$1;
                                       if(declared($1, concat(nom_methode, nom_classe))==1){printf("Erreur semantique a la ligne: %d, double declaration de l'attribut '%s'\n", nb_ligne, $1);} 
                                       else if(strcmp(sauvType, $3.type)!=0){
                                       printf("Erreur semantique a la ligne: %d, incompatibilite de type, affectation %s de type %s ---> '%s' de type %s\n", nb_ligne, $3.val, $3.type, $1, sauvType);}
                                       else{
                                          inserer($1, final+5, nom_methode, nom_classe, sauvPriv, sauvType, 0, 0, 0); 
                                        
										            insererQuad("=", $3.val, "", $1);

										            tab_niv_quad[ind_niv].num_quad = qc-1;
										            tab_niv_quad[ind_niv].niveau = niv_imbrication;
										            ind_niv++;
                                       };
                                       sauvPriv=1; final = 0;
                                    }
;

/*=============== declaration constantes ===========*/
declaration_const : FINAL type {final = 1;} liste_c 
;

/*================ declaration tableaux ============*/
declaration_tab : type '[' ']' liste_v
                | type '[' ']' liste_t_new  {initialise=0;}
                | type '[' ']' IDF '=' {num1=2;} '{' arguments '}' { initialise=1;
                                                                     if(declared($4, concat(nom_methode, nom_classe))==1){printf("Erreur semantique  a la ligne: %d, double declaration du tableau '%s'\n", nb_ligne, $4);} 
                                                                     else{if(!final){
                                                                                       inserer($4, 5, nom_methode, nom_classe, sauvPriv, $1, 0, 1, nb_argument);

                                                                                       char ss[20];
                                                                                       char s1[20];
						                                                                     sprintf(ss,"%d",nb_argument-1);
						                                                                     sprintf(s1,"%d",0);
                                                                                       insererQuad("BOUNDS",s1,ss,"");
										                                                         tab_niv_quad[ind_niv].num_quad = qc-1;
										                                                         tab_niv_quad[ind_niv].niveau = niv_imbrication;
										                                                         ind_niv++;

                                                                                       insererQuad("ADEC",$4,"","");
                                                                                       tab_niv_quad[ind_niv].num_quad = qc-1;
										                                                         tab_niv_quad[ind_niv].niveau = niv_imbrication;
										                                                         ind_niv++;
                                                                                    }
                                                                     }; 
                                                                     num1=0; final=0; sauvPriv=1; nb_argument = 0;
                                                                  }
;

liste_t_new : corp type '[' ENTIER ']' ',' liste_t_new   {
                                                            if(strcmp(sauvType1, sauvType)!=0){printf("Erreur semantique a la ligne: %d, incompatibilite de type lors de la declaration du tableau '%s'\n", nb_ligne, $1);}
                                                            else if(atoi($4)<1){printf("Erreur semantique a la ligne: %d, un tableau ('%s') ne peut avoir une taille negative\n", nb_ligne, $1);}
                                                            else{
                                                               inserer($1, 5, nom_methode, nom_classe, sauvPriv, sauvType1, 0, 1, atoi($4));

                                                               char ss[20];
                                                               char s1[20];
						                                             sprintf(ss,"%d",atoi($4)-1);
						                                             sprintf(s1,"%d",0);
                                                               insererQuad("BOUNDS",s1,ss,"");
										                                 tab_niv_quad[ind_niv].num_quad = qc-1;
										                                 tab_niv_quad[ind_niv].niveau = niv_imbrication;
										                                 ind_niv++;

                                                               insererQuad("ADEC",$1,"","");
                                                               tab_niv_quad[ind_niv].num_quad = qc-1;
										                                 tab_niv_quad[ind_niv].niveau = niv_imbrication;
										                                 ind_niv++;
                                                            }; 
                                                            sauvPriv=1;
                                                         }

            | corp type '[' ENTIER ']'                   {
                                                            if(strcmp(sauvType1, sauvType)!=0){printf("Erreur semantique a la ligne: %d, incompatibilite de type lors de la declaration du tableau '%s'\n", nb_ligne, $1);}
                                                            else if(atoi($4)<1){printf("Erreur semantique a la ligne: %d, un tableau ('%s') ne peut avoir une taille negative\n", nb_ligne, $1);}
                                                            else{
                                                               inserer($1, 5, nom_methode, nom_classe, sauvPriv, sauvType1, 0, 1, atoi($4));

                                                               char ss[20];
                                                               char s1[20];
						                                             sprintf(ss,"%d",atoi($4)-1);
						                                             sprintf(s1,"%d",0);
                                                               insererQuad("BOUNDS",s1,ss,"");
										                                 tab_niv_quad[ind_niv].num_quad = qc-1;
										                                 tab_niv_quad[ind_niv].niveau = niv_imbrication;
										                                 ind_niv++;

                                                               insererQuad("ADEC",$1,"","");
                                                               tab_niv_quad[ind_niv].num_quad = qc-1;
										                                 tab_niv_quad[ind_niv].niveau = niv_imbrication;
										                                 ind_niv++;
                                                            }; 
                                                            sauvPriv=1;
                                                         }
;

corp: IDF '=' NEW {$$ = $1; sauvType1 = sauvType; if(declared($1, concat(nom_methode, nom_classe))==1){printf("Erreur semantique a la ligne: %d, double declaration du tableau '%s'\n",nb_ligne, $1);};}
;

/*================ declaration matrices ============*/
declaration_mat : type '[' ']' '[' ']' liste_v   
                | type '[' ']' '[' ']' liste_m_new  {initialise=0;}
                | A argmts '}'   {
                                    if(!final) {   initialise=1;
                                                   inserer(nom, 5, nom_methode, nom_classe, sauvPriv, sauvType, 0, nb_tab_ligne, $2);
                                                   
                                                   char ss[20];
                                                   char s1[20];
						                                 sprintf(ss,"%d",nb_tab_ligne-1);
						                                 sprintf(s1,"%d",0);
                                                   insererQuad("BOUNDS",s1,ss,"");
										                     tab_niv_quad[ind_niv].num_quad = qc-1;
										                     tab_niv_quad[ind_niv].niveau = niv_imbrication;
										                     ind_niv++;

                                                   sprintf(ss,"%d",$2-1);
                                                   insererQuad("BOUNDS",s1,ss,"");
										                     tab_niv_quad[ind_niv].num_quad = qc-1;
										                     tab_niv_quad[ind_niv].niveau = niv_imbrication;
										                     ind_niv++;

                                                   insererQuad("ADEC",nom,"","");
                                                   tab_niv_quad[ind_niv].num_quad = qc-1;
										                     tab_niv_quad[ind_niv].niveau = niv_imbrication;
										                     ind_niv++;
                                    }; 
                                    num1=0; sauvPriv=1; nb_argument = 0; $2 = 0; nb_tab_ligne = 0; final=0;
                                 }
;
A : type '[' ']' '[' ']' IDF '=' '{' {nb_tab_ligne= 0; num1 = 2; nom=$6; if(declared($6, concat(nom_methode, nom_classe))==1){printf("Erreur semantique  a la ligne: %d, double declaration de la matrice '%s'\n", nb_ligne, $6);};} 
;

liste_m_new : corp type '[' ENTIER ']' '[' ENTIER ']' ',' liste_m_new   {
                                                                           if(strcmp(sauvType1, sauvType)!=0){printf("Erreur semantique a la ligne: %d, incompatibilite de type lors de la declaration du tableau '%s'\n", nb_ligne, $1);} 
                                                                           else if(atoi($4)<1 || atoi($7)<1){printf("Erreur semantique a la ligne: %d, un tableau ('%s') ne peut avoir une taille negative\n", nb_ligne, $1);}
                                                                           else{
                                                                              inserer($1, 5, nom_methode, nom_classe, sauvPriv, sauvType1, 0, atoi($4), atoi($7));

                                                                              char ss[20];
                                                                              char s1[20];
						                                                            sprintf(ss,"%d",atoi($4)-1);
						                                                            sprintf(s1,"%d",0);
                                                                              insererQuad("BOUNDS",s1,ss,"");
										                                                tab_niv_quad[ind_niv].num_quad = qc-1;
										                                                tab_niv_quad[ind_niv].niveau = niv_imbrication;
										                                                ind_niv++;

                                                                              sprintf(ss,"%d",atoi($7)-1);
                                                                              insererQuad("BOUNDS",s1,ss,"");
										                                                tab_niv_quad[ind_niv].num_quad = qc-1;
										                                                tab_niv_quad[ind_niv].niveau = niv_imbrication;
										                                                ind_niv++;

                                                                              insererQuad("ADEC",$1,"","");
                                                                              tab_niv_quad[ind_niv].num_quad = qc-1;
										                                                tab_niv_quad[ind_niv].niveau = niv_imbrication;
										                                                ind_niv++;
                                                                           }; 
                                                                           sauvPriv=1; nb_argument = 0;
                                                                        }
            | corp type '[' ENTIER ']' '[' ENTIER ']'                   {
                                                                           if(strcmp(sauvType1, sauvType)!=0){printf("Erreur semantique a la ligne: %d, incompatibilite de type lors de la declaration du tableau '%s'\n", nb_ligne, $1);} 
                                                                           else if(atoi($4)<1 || atoi($7)<1){printf("Erreur semantique a la ligne: %d, un tableau ('%s') ne peut avoir une taille negative\n", nb_ligne, $1);}
                                                                           else{
                                                                              inserer($1, 5, nom_methode, nom_classe, sauvPriv, sauvType1, 0, atoi($4), atoi($7));

                                                                              char ss[20];
                                                                              char s1[20];
						                                                            sprintf(ss,"%d",atoi($4)-1);
						                                                            sprintf(s1,"%d",0);
                                                                              insererQuad("BOUNDS",s1,ss,"");
										                                                tab_niv_quad[ind_niv].num_quad = qc-1;
										                                                tab_niv_quad[ind_niv].niveau = niv_imbrication;
										                                                ind_niv++;

                                                                              sprintf(ss,"%d",atoi($7)-1);
                                                                              insererQuad("BOUNDS",s1,ss,"");
										                                                tab_niv_quad[ind_niv].num_quad = qc-1;
										                                                tab_niv_quad[ind_niv].niveau = niv_imbrication;
										                                                ind_niv++;

                                                                              insererQuad("ADEC",$1,"","");
                                                                              tab_niv_quad[ind_niv].num_quad = qc-1;
										                                                tab_niv_quad[ind_niv].niveau = niv_imbrication;
										                                                ind_niv++;
                                                                           }; 
                                                                           sauvPriv=1; nb_argument = 0;
                                                                        }
;

argmts : B argmts           {nb_tab_ligne += 1; $$ = $1; if(nb_tab_col != $$){printf("Erreur semantique a la ligne: %d, le nombre de colonnes doit etre le meme pour toutes les lignes du tableau '%s'\n", nb_ligne, nom); final=1;};}
       | '{' arguments '}'  {nb_tab_col = nb_argument; nb_argument = 0; nb_tab_ligne += 1; $$ = $2; if(nb_tab_col != $$){printf("Erreur semantique a la ligne: %d, le nombre de colonnes doit etre le meme pour toutes les lignes du tableau '%s'\n", nb_ligne, nom);final=1;};}                                                         
;
B : '{' arguments '}' ','   {$$ = $2; nb_tab_col = nb_argument; nb_argument = 0;}
;

/*==================== INSTANCIATION ===============*/
instanciation : ID '(' liste_argument ')' {  if(!final){ if($3 != nb){printf("Erreur semantique a la ligne: %d, le nombre de parametres pour instancier l'objet '%s' doit etre le meme que celui de sa classe '%s'\n", nb_ligne, $1, ch);}
                                                         else {
                                                               inserer($1, 1, nom_methode, nom_classe, sauvPriv, ch, $3, 0, 0);
                                                               char* ch3; sprintf(ch3, "%d", $3);
                                                               insererQuad("CALL", sauvType1, "", ch3);
								                                       tab_niv_quad[ind_niv].num_quad = qc-1;
								                                       tab_niv_quad[ind_niv].niveau = niv_imbrication;
								                                       ind_niv++;
                                                         }
                                             }; 
                                             num1=0;final=0;sauvPriv=1; nb_argument = 0;
                                          }
;

ID : IDF IDF '=' NEW IDF {nb_argument = 0; $$=$2; num1=1; sauvType1=$1; ch=$1; char* ch = concat(nom_methode, nom_classe);if(declared($2, concat(nom_methode, nom_classe))==1){printf("Erreur semantique a la ligne: %d, double declaration de l'objet '%s'\n",nb_ligne, $2); final=1;}else if(declared($1, "")==0){printf("Erreur semantique a la ligne: %d, la classe '%s' est non declaree\n", nb_ligne, $1); final=1;}else if(strcmp($1, $5)!=0){printf("Erreur semantique a la ligne: %d, incompatibilite de type lors de l'instanciation de l'objet '%s'\n", nb_ligne, $2); final=1;}else{nb=getparametre($1, $1);}}
;

liste_argument : arguments {$$ = $1;}
               | {$$ = 0;}
;

arguments : exp ',' arguments {  nb_argument += 1; $$ = nb_argument; 
                                 if(num1==2){if(strcmp($1.type, sauvType)!=0){final=1; printf("Erreur semantique a la ligne: %d, incompatibilite entre le type de la valeur inseree et le type du tableau\n", nb_ligne);}} 
                                 else if(final!=1){type_para = rechercher_parametre(sauvType1, ch, nb-nb_argument+1); 
                                                   if(nb-nb_argument+1>0){type_para = rechercher_parametre(sauvType1, ch, nb-nb_argument+1); 
                                                                          if(strcmp($1.type, type_para)!=0){printf("Erreur semantique a la ligne: %d, incompatibilite entre le type de l'argument et le type du parametre %d qui est %s\n", nb_ligne, nb-nb_argument+1, type_para);}
                                                                          else{
                                                                              insererQuad("PARAM", $1.val, "", "");
								                                                      tab_niv_quad[ind_niv].num_quad = qc-1;
								                                                      tab_niv_quad[ind_niv].niveau = niv_imbrication;
								                                                      ind_niv++;
                                                                          }
                                                                          }
                                 };                                 
                              }
          | exp               {  nb_argument += 1; $$ = nb_argument; 
                                 if(num1==2){if(strcmp($1.type, sauvType)!=0){final=1; printf("Erreur semantique a la ligne: %d, incompatibilite entre le type de la valeur inseree et le type du tableau\n", nb_ligne);}} 
                                 else if(final!=1){type_para = rechercher_parametre(sauvType1, ch, nb-nb_argument+1); 
                                                   if(nb-nb_argument+1>0){type_para = rechercher_parametre(sauvType1, ch, nb-nb_argument+1); 
                                                                          if(strcmp($1.type, type_para)!=0){printf("Erreur semantique a la ligne: %d, incompatibilite entre le type de l'argument et le type du parametre %d qui est %s\n", nb_ligne, nb-nb_argument+1, type_para);}
                                                                          else{
                                                                              insererQuad("PARAM", $1.val, "", "");
								                                                      tab_niv_quad[ind_niv].num_quad = qc-1;
								                                                      tab_niv_quad[ind_niv].niveau = niv_imbrication;
								                                                      ind_niv++;
                                                                          }
                                                                          }
                                 };                                 
                              }
;

/*================================= declaration des constructeurs et methodes ============================*/
decl_constructor_methode : constructeur
                         | methode_void
                         | methode_return
;

/*============================= constructor ========================*/
constructeur : D '{' corp_methode '}' {if(nb_return >0){printf("Erreur semantique a la ligne: %d, le constructeur '%s' ne doit pas retourner une valeur\n", num, nom_methode);}; nom_methode = ""; nb_return = 0;}
             | E '{' corp_methode '}' {if(nb_return >0){printf("Erreur semantique a la ligne: %d, le constructeur '%s' ne doit pas retourner une valeur\n", num, nom_methode);}; nom_methode = ""; nb_return = 0;}
;
D : F '(' liste_parametre ')' {nb_argument = 0;num1=0;nb_parametre(nom_methode, nom_classe, $3);}
E : G '(' liste_parametre ')' {nb_argument = 0;num1=0;nb_parametre(nom_methode, nom_classe, $3);}
F : privacy1 IDF {nom_methode = $2; if(strcmp($2, nom_classe)!=0){printf("Erreur semantique a la ligne: %d, le constructeur '%s' doit avoir le meme nom que sa classe '%s'\n", nb_ligne, $2, nom_classe);}; if(declared($2, nom_classe)==1){printf("Erreur semantique a la ligne: %d, double declaration du constructeur '%s' dans la classe '%s'\n", nb_ligne, $2, nom_classe);} else{inserer($2, 3, "", nom_classe, sauvPriv, "", 0, 0, 0); insererQuad("PROC", nom_classe, "", ""); tab_niv_quad[ind_niv].num_quad = qc-1; tab_niv_quad[ind_niv].niveau = niv_imbrication; ind_niv++;};}
G : IDF          {nom_methode = $1; if(strcmp($1, nom_classe)!=0){printf("Erreur semantique a la ligne: %d, le constructeur '%s' doit avoir le meme nom que sa classe '%s'\n", nb_ligne, $1, nom_classe);}; if(declared($1, nom_classe)==1){printf("Erreur semantique a la ligne: %d, double declaration du constructeur '%s' dans la classe '%s'\n", nb_ligne, $1, nom_classe);} else{inserer($1, 3, "", nom_classe, 1, "", 0, 0, 0); insererQuad("PROC", nom_classe, "", ""); tab_niv_quad[ind_niv].num_quad = qc-1; tab_niv_quad[ind_niv].niveau = niv_imbrication; ind_niv++;}}

liste_parametre : parametres {$$ = $1;num1=0}
                | {$$ = 0;num1=0}
;

parametres : parametre ',' parametres {nb_argument += 1; $$ = nb_argument;}
           | parametre                {nb_argument += 1; $$ = nb_argument;}
;

parametre : type IDF                 {num1 += 1; $$ = num1; if(declared($2, concat(nom_methode, nom_classe))==1){printf("Erreur semantique a la ligne: %d, double declaration du parametre '%s'\n", nb_ligne, $2);} else{inserer($2, 5, nom_methode, nom_classe, 0, $1, num1, 0, 0);}}
          | type '[' ']' IDF         {num1 += 1; $$ = num1; if(declared($4, concat(nom_methode, nom_classe))==1){printf("Erreur semantique a la ligne: %d, double declaration du parametre '%s'\n", nb_ligne, $4);} else{inserer($4, 5, nom_methode, nom_classe, 0, $1, num1, 0, 0);}}
          | type '[' ']' '[' ']' IDF {num1 += 1; $$ = num1; if(declared($6, concat(nom_methode, nom_classe))==1){printf("Erreur semantique a la ligne: %d, double declaration du parametre '%s'\n", nb_ligne, $6);} else{inserer($6, 5, nom_methode, nom_classe, 0, $1, num1, 0, 0);}}
;

/*============================== methode ==========================*/
methode_void : H '{' corp_methode '}' {if(nb_return >0){printf("Erreur semantique a la ligne: %d, la methode '%s' ne doit pas retourner une valeur\n", num, nom_methode);}; nom_methode = ""; nb_return = 0;}
             | I '{' corp_methode '}' {if(nb_return >0){printf("Erreur semantique a la ligne: %d, la methode '%s' ne doit pas retourner une valeur\n", num, nom_methode);}; nom_methode = ""; nb_return = 0;}
             | J '{' corp_methode '}' {if(nb_return >0){printf("Erreur semantique a la ligne: %d, la methode '%s' ne doit pas retourner une valeur\n", num, nom_methode);}; nom_methode = ""; nb_return = 0;}
             | K '{' corp_methode '}' {if(nb_return >0){printf("Erreur semantique a la ligne: %d, la methode '%s' ne doit pas retourner une valeur\n", num, nom_methode);}; nom_methode = ""; nb_return = 0;}
             | L '{' corp_methode '}' {if(nb_return >0){printf("Erreur semantique a la ligne: %d, la methode '%s' ne doit pas retourner une valeur\n", num, nom_methode);}; nom_methode = ""; nb_return = 0;}
             | M '{' corp_methode '}' {if(nb_return >0){printf("Erreur semantique a la ligne: %d, la methode '%s' ne doit pas retourner une valeur\n", num, nom_methode);}; nom_methode = ""; nb_return = 0;}
;
H : M '(' liste_parametre ')' {nb_argument = 0;num1=0; nb_parametre(nom_methode, nom_classe, $3);}
I : N '(' liste_parametre ')' {nb_argument = 0;num1=0; nb_parametre(nom_methode, nom_classe, $3);}
J : O '(' liste_parametre ')' {nb_argument = 0;num1=0; nb_parametre(nom_methode, nom_classe, $3);}
K : P '(' liste_parametre ')' {nb_argument = 0;num1=0; nb_parametre(nom_methode, nom_classe, $3);}
L : Q '(' liste_parametre ')' {nb_argument = 0;num1=0; nb_parametre(nom_methode, nom_classe, $3);}
M : R '(' liste_parametre ')' {nb_argument = 0;num1=0; nb_parametre(nom_methode, nom_classe, $3);}
N : privacy VOID IDF     {nom_methode = $3; if(declared($3, nom_classe)==1){printf("Erreur semantique a la ligne: %d, double declaration de la methode '%s'\n", nb_ligne, $3);} else{inserer($3, 2, "", nom_classe, sauvPriv, "void", 0, 0, 0); insererQuad("PROC", nom_methode, nom_classe, ""); tab_niv_quad[ind_niv].num_quad = qc-1; tab_niv_quad[ind_niv].niveau = niv_imbrication; ind_niv++;};}
O : privacy1 VOID IDF    {nom_methode = $3; if(declared($3, nom_classe)==1){printf("Erreur semantique a la ligne: %d, double declaration de la methode '%s'\n", nb_ligne, $3);} else{inserer($3, 2, "", nom_classe, sauvPriv, "void", 0, 0, 0); insererQuad("PROC", nom_methode, nom_classe, ""); tab_niv_quad[ind_niv].num_quad = qc-1; tab_niv_quad[ind_niv].niveau = niv_imbrication; ind_niv++;};}
P : VOID IDF             {nom_methode = $2; if(declared($2, nom_classe)==1){printf("Erreur semantique a la ligne: %d, double declaration de la methode '%s'\n", nb_ligne, $2);} else{inserer($2, 2, "", nom_classe, 1, "void", 0, 0, 0); insererQuad("PROC", nom_methode, nom_classe, ""); tab_niv_quad[ind_niv].num_quad = qc-1; tab_niv_quad[ind_niv].niveau = niv_imbrication; ind_niv++;};}
Q : privacy VOID SETTER  {nom_methode = $3; if(declared($3, nom_classe)==1){printf("Erreur semantique a la ligne: %d, double declaration de la methode '%s'\n", nb_ligne, $3);} else{inserer($3, 2, "", nom_classe, sauvPriv, "void", 0, 0, 0); insererQuad("PROC", nom_methode, nom_classe, ""); tab_niv_quad[ind_niv].num_quad = qc-1; tab_niv_quad[ind_niv].niveau = niv_imbrication; ind_niv++;};}
R : privacy1 VOID SETTER {nom_methode = $3; if(declared($3, nom_classe)==1){printf("Erreur semantique a la ligne: %d, double declaration de la methode '%s'\n", nb_ligne, $3);} else{inserer($3, 2, "", nom_classe, sauvPriv, "void", 0, 0, 0); insererQuad("PROC", nom_methode, nom_classe, ""); tab_niv_quad[ind_niv].num_quad = qc-1; tab_niv_quad[ind_niv].niveau = niv_imbrication; ind_niv++;};}
S : VOID SETTER          {nom_methode = $2; if(declared($2, nom_classe)==1){printf("Erreur semantique a la ligne: %d, double declaration de la methode '%s'\n", nb_ligne, $2);} else{inserer($2, 2, "", nom_classe, 1, "void", 0, 0, 0); insererQuad("PROC", nom_methode, nom_classe, ""); tab_niv_quad[ind_niv].num_quad = qc-1; tab_niv_quad[ind_niv].niveau = niv_imbrication; ind_niv++;};}

methode_return : T '{' corp_methode '}' {if(nb_return <1){printf("Erreur semantique, la methode '%s' de la classe %s doit retourner une valeur\n", nom_methode, nom_classe);}; nom_methode = ""; nb_return = 0;}
               | U '{' corp_methode '}' {if(nb_return <1){printf("Erreur semantique, la methode '%s' de la classe %s doit retourner une valeur\n", nom_methode, nom_classe);}; nom_methode = ""; nb_return = 0;}
               | V '{' corp_methode '}' {if(nb_return <1){printf("Erreur semantique, la methode '%s' de la classe %s doit retourner une valeur\n", nom_methode, nom_classe);}; nom_methode = ""; nb_return = 0;}
               | W '{' corp_methode '}' {if(nb_return <1){printf("Erreur semantique, la methode '%s' de la classe %s doit retourner une valeur\n", nom_methode, nom_classe);}; nom_methode = ""; nb_return = 0;}
               | X '{' corp_methode '}' {if(nb_return <1){printf("Erreur semantique, la methode '%s' de la classe %s doit retourner une valeur\n", nom_methode, nom_classe);}; nom_methode = ""; nb_return = 0;}
               | Y '{' corp_methode '}' {if(nb_return <1){printf("Erreur semantique, la methode '%s' de la classe %s doit retourner une valeur\n", nom_methode, nom_classe);}; nom_methode = ""; nb_return = 0;}
;
T : TA '(' liste_parametre ')' {nb_argument = 0;num1=0;nb_parametre(nom_methode, nom_classe, $3);}
U : UA '(' liste_parametre ')' {nb_argument = 0;num1=0;nb_parametre(nom_methode, nom_classe, $3);}
V : VA '(' liste_parametre ')' {nb_argument = 0;num1=0;nb_parametre(nom_methode, nom_classe, $3);} 
W : privacy type GETTER '(' ')'  {nom_methode = $3; if(declared($3, nom_classe)==1){printf("Erreur semantique a la ligne: %d, double declaration de la methode '%s'\n", nb_ligne, $3);} else{inserer($3, 2, "", nom_classe, $1, $2, 0, 0, 0); insererQuad("PROC", nom_methode, nom_classe, ""); tab_niv_quad[ind_niv].num_quad = qc-1; tab_niv_quad[ind_niv].niveau = niv_imbrication; ind_niv++;}; nb_argument = 0;} 
X : privacy1 type GETTER '(' ')' {nom_methode = $3; if(declared($3, nom_classe)==1){printf("Erreur semantique a la ligne: %d, double declaration de la methode '%s'\n", nb_ligne, $3);} else{inserer($3, 2, "", nom_classe, $1, $2, 0, 0, 0); insererQuad("PROC", nom_methode, nom_classe, ""); tab_niv_quad[ind_niv].num_quad = qc-1; tab_niv_quad[ind_niv].niveau = niv_imbrication; ind_niv++;}; nb_argument = 0;} 
Y : type GETTER '(' ')'          {nom_methode = $2; if(declared($2, nom_classe)==1){printf("Erreur semantique a la ligne: %d, double declaration de la methode '%s'\n", nb_ligne, $2);} else{inserer($2, 2, "", nom_classe, 1, $1, 0, 0, 0); insererQuad("PROC", nom_methode, nom_classe, ""); tab_niv_quad[ind_niv].num_quad = qc-1; tab_niv_quad[ind_niv].niveau = niv_imbrication; ind_niv++;}; nb_argument = 0;} 
TA : privacy type IDF  {nom_methode = $3; sauvType1=$2; if(declared($3, nom_classe)==1){printf("Erreur semantique a la ligne: %d, double declaration de la methode '%s'\n", nb_ligne, $3);} else{inserer($3, 2, "", nom_classe, sauvPriv, sauvType1, 0, 0, 0); insererQuad("PROC", nom_methode, nom_classe, ""); tab_niv_quad[ind_niv].num_quad = qc-1; tab_niv_quad[ind_niv].niveau = niv_imbrication; ind_niv++;};} 
UA : privacy1 type IDF {nom_methode = $3; sauvType1=$2; if(declared($3, nom_classe)==1){printf("Erreur semantique a la ligne: %d, double declaration de la methode '%s'\n", nb_ligne, $3);} else{inserer($3, 2, "", nom_classe, sauvPriv, sauvType1, 0, 0, 0); insererQuad("PROC", nom_methode, nom_classe, ""); tab_niv_quad[ind_niv].num_quad = qc-1; tab_niv_quad[ind_niv].niveau = niv_imbrication; ind_niv++;};} 
VA : type IDF          {nom_methode = $2; sauvType1=$1; if(declared($2, nom_classe)==1){printf("Erreur semantique a la ligne: %d, double declaration de la methode '%s'\n", nb_ligne, $2);} else{inserer($2, 2, "", nom_classe, 1, sauvType1, 0, 0, 0); insererQuad("PROC", nom_methode, nom_classe, ""); tab_niv_quad[ind_niv].num_quad = qc-1; tab_niv_quad[ind_niv].niveau = niv_imbrication; ind_niv++;};}

corp_methode : {sauvPriv = 1;} instruction_simple corp_methode  
             | {sauvPriv = 1;} instruction_complexe corp_methode
             | {sauvPriv = 1;}
;

instruction_simple : decl_attribut
                   | inst_print
                   | inst_aff ';'
                   | RETURN  exp ';'   {
                                          nb_return += 1; num = nb_ligne; 
                                          if(declared(nom_methode, concat(nom_methode, nom_classe))==1){nom = gettype(nom_methode, nom_classe); if(strcmp($2.type, nom)!=0){printf("Erreur semantique a la ligne: %d, incompatibilite de type: le type de retour doit etre un %s\n", nb_ligne, nom);}
                                             else{
                                                insererQuad("RETURN", $2.val, $2.type, "");
								                        tab_niv_quad[ind_niv].num_quad = qc-1;
								                        tab_niv_quad[ind_niv].niveau = niv_imbrication;
								                        ind_niv++;
                                             }
                                          }; 
                                          nom="";
                                       }
                   | appel_methode ';' 
                   | exp1 ';'
                   | inst_throw_exeption
;

instruction_complexe : inst_if
                     | inst_for
                     | inst_while
                     | inst_dowhile
                     | inst_switchcase
                     | inst_exeption
;

exp1  : left_value signe  {
                              if(sauvPriv){
                                 sprintf(tmp, "t%d", compteur++);
                                 insererQuad($2, $1.val, "1", tmp);
                     
                                 tab_niv_quad[ind_niv].num_quad = qc-1;
                                 tab_niv_quad[ind_niv].niveau = niv_imbrication;
                                 ind_niv++;

                                 insererQuad("=", tmp, "", $1.val);
                     
                                 tab_niv_quad[ind_niv].num_quad = qc-1;
                                 tab_niv_quad[ind_niv].niveau = niv_imbrication;
                                 ind_niv++;
                              };
                              sauvPriv=1;
                           }
;

signe : ADDADD {$$="+";}
      | SUBSUB {$$="-";}
;

/*================== PRINT ================*/
inst_print : PRINT '(' {verif=0;} exprs_print ')' ';' {
                                                         verif=1;
                                                         insererQuad("PRINTLN", "", "", "");
								                                 tab_niv_quad[ind_niv].num_quad = qc-1;
								                                 tab_niv_quad[ind_niv].niveau = niv_imbrication;
								                                 ind_niv++;
                                                      }
;

exprs_print : exprsp
            |
;

exprsp : exprsp ADD exprsp
       | '(' exp ')' {
                        insererQuad("PRINT", $2.val, $2.type, "");
								tab_niv_quad[ind_niv].num_quad = qc-1;
								tab_niv_quad[ind_niv].niveau = niv_imbrication;
								ind_niv++;
                     }
       | valeur      {
                        insererQuad("PRINT", $1.val, $1.type, "");
								tab_niv_quad[ind_niv].num_quad = qc-1;
								tab_niv_quad[ind_niv].niveau = niv_imbrication;
								ind_niv++;
                     }
;

/*============== IF / ELSE =============*/
inst_if : bloc_if else_if  {
                              while(!pileVide(pile_br_un)){  
											int num_quad_br;
											desempiler(&pile_br_un, &num_quad_br);
											char qc_char[10];
											sprintf(qc_char, "%d", qc);
											majQuadBR(num_quad_br, 1, qc_char);
										}
                           }
;

/*------------ IF ----------*/
bloc_if : deb_bloc_if corps_if {
                                 //comment stocker le BR vers la fin lorsque le if est fini
											int num_quad;
                                 desempiler(&pile_br_bin, &num_quad);

											char num_quad_courant[10];
											sprintf(num_quad_courant, "%d", qc+1);
											majQuad(num_quad, 1, num_quad_courant);
                                 
                                 if(!pileVide(pile_br_bin_and)){
                                    desempiler(&pile_br_bin_and, &num_quad);
                                    if(num_quad != -1){majQuad(num_quad, 1, num_quad_courant);}

                                    int w=1;
                                    while(!pileVide(pile_br_bin_and) && w){  
                                       desempiler(&pile_br_bin_and, &num_quad);
                                       if(num_quad != -1){majQuad(num_quad, 1, num_quad_courant);}
                                       else{w=0;}
							               }
                                 }

											//generer (BR, fin_if, , )
											empiler(&pile_br_un, qc);
											insererQuad("BR", "", "", "");
											
											//gerer l'omptimisation au niveau des if
											niv_imbrication--;
											tab_niv_quad[ind_niv].num_quad = qc-1;
											tab_niv_quad[ind_niv].niveau = niv_imbrication;
											ind_niv++;
                              }
;

deb_bloc_if : IF '(' cond ')' imbric   {
													   //recuperer le numero du dernier quad [qc-1] de la derniere condition qu'on vient juste d'inserer
                                          int num_quad;
                                          char num_quad_courant[10];
											         sprintf(num_quad_courant, "%d", qc);

                                          while(!pileVide(pile_br_bin_or)){
                                             desempiler(&pile_br_bin_or, &num_quad);
                                             desempiler(&pile_br_bin_or, &num_quad);
                                             majQuad(num_quad, 1, num_quad_courant);
                                          }

                                          if(!pileVide(pile_br_bin_and)){empiler(&pile_br_bin_and, -1);}
                                          empiler(&pile_br_bin, qc-1);
                                          dans_if =0;
													}
;

corps_if : instruction_simple
         | '{' corp_methode '}'
;

imbric: {niv_imbrication++;}
;

/*----- ELSE IF/ ELSE -----*/
else_if : ELSE bloc_if  else_if
        | ELSE imbric corps_if {niv_imbrication--;}
        |
;

/*================ WHILE  ===========*/
inst_while : deb_while '{' corp_methode '}'  {
                                                //comment stocker le BR vers la debut pour la prochaine boucle
											               int num_quad;
                                                desempiler(&pile_br_bin, &num_quad);

											               char num_quad_courant[10];
											               sprintf(num_quad_courant, "%d", qc+1);
											               majQuad(num_quad, 1, num_quad_courant);
                                 
                                                if(!pileVide(pile_br_bin_and)){
                                                   desempiler(&pile_br_bin_and, &num_quad);
                                                   if(num_quad != -1){majQuad(num_quad, 1, num_quad_courant);}

                                                   int w=1;
                                                   while(!pileVide(pile_br_bin_and) && w){  
                                                      desempiler(&pile_br_bin_and, &num_quad);
                                                      if(num_quad != -1){majQuad(num_quad, 1, num_quad_courant);}
                                                      else{w=0;}
							                              }
                                                }

											               //generer (BR, deb_quad_while, , )
                                                desempiler(&pile_deb_quad, &num_quad);
                                                sprintf(num_quad_courant, "%d", num_quad);
											               insererQuad("BR", num_quad_courant, "", "");
											
											               //gerer l'omptimisation au niveau des boucles
											               niv_imbrication--;
											               tab_niv_quad[ind_niv].num_quad = qc-1;
											               tab_niv_quad[ind_niv].niveau = niv_imbrication;
											               ind_niv++;
                                             }
;

deb_while : WHILE {empiler(&pile_deb_quad, qc);} '(' cond ')'  imbric  
            {
					//recuperer le numero du dernier quad [qc-1] de la derniere condition qu'on vient juste d'inserer
               int num_quad;
               char num_quad_courant[10];
					sprintf(num_quad_courant, "%d", qc);

               while(!pileVide(pile_br_bin_or)){
                  desempiler(&pile_br_bin_or, &num_quad);
                  desempiler(&pile_br_bin_or, &num_quad);
                  majQuad(num_quad, 1, num_quad_courant);
               }

               if(!pileVide(pile_br_bin_and)){empiler(&pile_br_bin_and, -1);}
               empiler(&pile_br_bin, qc-1);
               dans_if =0;
				}
;


/*=============== DO WHILE ============*/
inst_dowhile : DO {empiler(&pile_deb_quad, qc);} imbric '{' corp_methode '}' WHILE '(' cond ')' ';'   
               {
                  //recuperer le numero du dernier quad [qc-1] de la derniere condition qu'on vient juste d'inserer
                  int num_quad;
                  char num_quad_courant[10];
						desempiler(&pile_deb_quad, &num_quad);
                  sprintf(num_quad_courant, "%d", num_quad);

                  while(!pileVide(pile_br_bin_or)){
                     desempiler(&pile_br_bin_or, &num_quad);
                     desempiler(&pile_br_bin_or, &num_quad);
                     majQuad(num_quad, 1, num_quad_courant);
                  }
                                                                                                
                  //comment stocker le BR vers le debut pour la prochaine boucle 
                  if(dans_if!=1){majQuad(qc-1, 1, num_quad_courant);}
						else{
                     insererQuad("BR", num_quad_courant, "", "");
                     sprintf(num_quad_courant, "%d", qc); 
                     majQuad(qc-2, 1, num_quad_courant); 
                  }
                                 
                  int w=1;
                  while(!pileVide(pile_br_bin_and) && w){  
                     desempiler(&pile_br_bin_and, &num_quad);
                     if(num_quad != -1){majQuad(num_quad, 1, num_quad_courant);}
                     else{w=0;}
						}

						//gerer l'omptimisation au niveau des boucles
						niv_imbrication--;
						tab_niv_quad[ind_niv].num_quad = qc-1;
						tab_niv_quad[ind_niv].niveau = niv_imbrication;
						ind_niv++;
                  dans_if =0;
               }
;


/*================= FOR ================*/
inst_for : FOR '(' clause ')' '{' corp_methode '}'   
            {
               int num_quad;
               char num_quad_courant[10];
               int sommet_pile = sommetPile(exp_for);

               if(sommet_pile){
                  char s1[20];
					   sprintf(s1,"%d",1);
                  sprintf(tmp, "t%d", compteur++);
                  insererQuad("+", $3, s1, tmp);
                     
                  tab_niv_quad[ind_niv].num_quad = qc-1;
                  tab_niv_quad[ind_niv].niveau = niv_imbrication;
                  ind_niv++;

                  insererQuad("=", tmp, "", $3);
                     
                  tab_niv_quad[ind_niv].num_quad = qc-1;
                  tab_niv_quad[ind_niv].niveau = niv_imbrication;
                  ind_niv++;

					   desempiler(&pile_deb_quad, &num_quad);

					   sprintf(num_quad_courant, "%d", qc+1);
					   majQuad(num_quad, 1, num_quad_courant);

                  sprintf(num_quad_courant, "%d", num_quad);
                  //generer (BR, deb_for, , )
					   insererQuad("BR", num_quad_courant, "", "");
               }
               else{
                  int num_quad;
                  desempiler(&pile_br_bin, &num_quad);
						sprintf(num_quad_courant, "%d", num_quad);

                  insererQuad("BR", num_quad_courant, "", "");
						tab_niv_quad[ind_niv].num_quad = qc-1;
						tab_niv_quad[ind_niv].niveau = niv_imbrication;
						ind_niv++;

                  int num_br_un_exp;
                  desempiler(&pile_br_bin, &num_br_un_exp);
                  sprintf(num_quad_courant, "%d", qc);
                  majQuad(num_br_un_exp, 1, num_quad_courant);

                  desempiler(&pile_br_bin, &num_quad);

						char num_quad_courant[10];
						sprintf(num_quad_courant, "%d", qc+1);
						majQuad(num_quad, 1, num_quad_courant);
                                 
                  if(!pileVide(pile_br_bin_and)){
                     desempiler(&pile_br_bin_and, &num_quad);
                     if(num_quad != -1){majQuad(num_quad, 1, num_quad_courant);}

                     int w=1;
                     while(!pileVide(pile_br_bin_and) && w){  
                        desempiler(&pile_br_bin_and, &num_quad);
                        if(num_quad != -1){majQuad(num_quad, 1, num_quad_courant);}
                        else{w=0;}
						   }
                  }

                  desempiler(&pile_deb_quad, &num_quad);
                  sprintf(num_quad_courant, "%d", num_quad);

                  //generer (BR, deb_for, , )
					   insererQuad("BR", num_quad_courant, "", "");
               }
											
					//gerer l'omptimisation au niveau des boucles
					niv_imbrication--;
					tab_niv_quad[ind_niv].num_quad = qc-1;
					tab_niv_quad[ind_niv].niveau = niv_imbrication;
					ind_niv++;

               desempiler(&exp_for, &sommet_pile);
         }
;

clause : dec_for condition expf  {  $$=$1;
                                    empiler(&exp_for, 0);
                                    int num_quad;
                                    desempiler(&pile_br_bin, &num_quad);

                                    char num_quad_courant[10];
					                     sprintf(num_quad_courant, "%d", qc+1);
                                    majQuad(num_quad, 1, num_quad_courant);

                                    insererQuad("BR", "", "", "");
                                    empiler(&pile_br_bin, qc-1);
					                     tab_niv_quad[ind_niv].num_quad = qc-1;
					                     tab_niv_quad[ind_niv].niveau = niv_imbrication;
					                     ind_niv++;

                                    empiler(&pile_br_bin, num_quad+1);
                                 }

       | dec1 ':' exp   imbric   {  $$=$1;
                                    empiler(&exp_for, 1);
                                    if(!initialise){
                                       insererQuad("=", "0", "", $1);
                                       tab_niv_quad[ind_niv].num_quad = qc-1;
									            tab_niv_quad[ind_niv].niveau = niv_imbrication;
									            ind_niv++;
                                    }
                                    insererQuad("BGE", "", $1, $3.val);
                                    empiler(&pile_deb_quad, qc-1);
											
									         tab_niv_quad[ind_niv].num_quad = qc-1;
									         tab_niv_quad[ind_niv].niveau = niv_imbrication;
									         ind_niv++;
                                 }
;

dec_for: dec ';'  {  $$=$1;
                     if(!initialise){
                        insererQuad("=", "0", "", $1);
                        tab_niv_quad[ind_niv].num_quad = qc-1;
						      tab_niv_quad[ind_niv].niveau = niv_imbrication;
						      ind_niv++;
                     }
                     empiler(&pile_deb_quad, qc);
                  }
;

condition: cond ';'  {
					         //recuperer le numero du dernier quad [qc-1] de la derniere condition qu'on vient juste d'inserer
                        int num_quad;
                        char num_quad_courant[10];
					         sprintf(num_quad_courant, "%d", qc);

                        while(!pileVide(pile_br_bin_or)){
                           desempiler(&pile_br_bin_or, &num_quad);
                           desempiler(&pile_br_bin_or, &num_quad);
                           majQuad(num_quad, 1, num_quad_courant);
                        }

                        if(!pileVide(pile_br_bin_and)){empiler(&pile_br_bin_and, -1);}
                        empiler(&pile_br_bin, qc-1);

					         insererQuad("BR", "", "", "");
                        empiler(&pile_br_bin, qc-1);
					         tab_niv_quad[ind_niv].num_quad = qc-1;
					         tab_niv_quad[ind_niv].niveau = niv_imbrication;
					         ind_niv++;
                        
                        dans_if =0;
				         }
;

dec : declaration_var {$$=$1;}
    | inst_aff {$$=$1;}
;

dec1 : declaration_var {$$=$1;}
     | valeur1 {$$=$1.val;}
;

expf : inst_aff
     | exp1
     |
;

/*============= SWITCH CASE ============*/
inst_switchcase : SWITCH '(' exp ')' imbric {empiler1(&exp_switch_type, $3.type); empiler1(&exp_switch, $3.val);} '{' liste_case default_case '}' {char *expre; desempiler1(&exp_switch, &expre); desempiler1(&exp_switch_type, &expre);}
                  {
                     while(!pileVide(pile_br_un_switch))
							{  
								int num_quad_br;
								desempiler(&pile_br_un_switch, &num_quad_br);
								char qc_char[10];
								sprintf(qc_char, "%d", qc);
								majQuadBR(num_quad_br, 1, qc_char);
							}
                  }
;

liste_case : case liste_case
           |
;

case: deb_case corp_methode BREAK ';' {
                                          int num_quad;
                                          desempiler(&quad_br_bin_switch, &num_quad);

                                          char num_quad_courant[10];
                                          sprintf(num_quad_courant, "%d", qc+1);

                                          majQuad(num_quad, 1, num_quad_courant);

                                          insererQuad("BR", "", "", "");
                                          empiler(&pile_br_un_switch, qc-1);
											
											         //gerer l'omptimisation au niveau des case
											         niv_imbrication--;
											         tab_niv_quad[ind_niv].num_quad = qc-1;
											         tab_niv_quad[ind_niv].niveau = niv_imbrication;
											         ind_niv++;
                                       }
;

deb_case : CASE valeur ':'   {   
                                 char *expre; char *typexp;
                                 expre = strdup(sommetPile1(exp_switch));
                                 typexp = strdup(sommetPile1(exp_switch_type));
                                 if(strcmp($2.type, typexp)!=0){printf("Erreur semantique a la ligne: %d, incompatibilite de type, affectation %s de type %s ---> '%s' de type %s\n", nb_ligne, $2.val, $2.type, expre, typexp);}
                                
                                 insererQuad("BNE","",expre,$2.val);
                                 tab_niv_quad[ind_niv].num_quad = qc-1;
											tab_niv_quad[ind_niv].niveau = niv_imbrication;
											ind_niv++;
                                 empiler(&quad_br_bin_switch, qc-1);
                              }
;

default_case : DEFAULT ':' corp_methode
             |
;

/*============== EXCEPTIONS =============*/
inst_throw_exeption : THROW NEW IDF '(' STRING ')' ';' {if(declared($3, concat(nom_methode, nom_classe))==1){printf("Erreur semantique a la ligne: %d, double declaration de l'attribut '%s'\n",nb_ligne, $3);} else{inserer($3, 4, nom_methode, nom_classe, 1, sauvType, 0, 0, 0);};}
;

inst_exeption : TRY '{' corp_methode '}' liste_catch finally
; 

liste_catch : catch_block liste_catch
            | catch_block
;

catch_block : CATCH '(' IDF IDF ')' '{' corp_methode '}'  {if(declared($3, concat(nom_methode, nom_classe))==0){printf("Erreur semantique a la ligne: %d, l'exception '%s' est non declaree\n", nb_ligne, $3);} else{inserer($4, 5, nom_methode, nom_classe, 1, $3, 0, 0, 0);};}
;

finally : FINALLY '{' corp_methode '}'
        |
;

/*============ APPEL METHODE ===========*/
appel_methode : liste_d '('liste_argument')' {  if(!final) {if(nom == ""){
                                                               sauvPriv = getparametre($1, nom_classe); 
                                                               if(sauvPriv!= $3){printf("Erreur semantique a la ligne: %d, la methode '%s' a %d parametres\n", nb_ligne, $1, sauvPriv);}
                                                               else{ $$.val = $1; $$.type = gettype($1, nom_classe);
                                                                     char ch4[5]; sprintf(ch4, "%d", getparametre($1, nom_classe));
                                                                     printf("%d", getparametre($1, nom_classe));
                                                                     insererQuad("CALL", $1, nom_classe, ch);
										                                       tab_niv_quad[ind_niv].num_quad = qc-1;
										                                       tab_niv_quad[ind_niv].niveau = niv_imbrication;
										                                       ind_niv++;
                                                                  }
                                                            }
                                                            else{
                                                               sauvPriv = getparametre($1, nom); 
                                                               if(sauvPriv!= $3){printf("Erreur semantique a la ligne: %d, la methode '%s' a %d parametres\n", nb_ligne, $1, sauvPriv);}
                                                               else{ $$.val = $1; $$.type = gettype($1, nom);
                                                                     char ch4[5]; sprintf(ch4, "%d", getparametre($1, nom));
                                                                     insererQuad("CALL", $1, nom, ch);
										                                       tab_niv_quad[ind_niv].num_quad = qc-1;
										                                       tab_niv_quad[ind_niv].niveau = niv_imbrication;
										                                       ind_niv++;
                                                               }
                                                            }};
                                                sauvPriv=1;final = 0; num1=0;
                                             }
;

liste_d : IDF '.' IDF   {$$ = $3; num1=1; nom = ""; if(strcmp($1, nom_classe)!=0){if(declared($1, concat(nom_methode, nom_classe))==0){final = 1; printf("Erreur semantique a la ligne: %d, l'objet '%s' est non declare\n", nb_ligne, $1);}else{nom = gettype($1, concat(nom_methode, nom_classe)); if(declared($3, nom)==0){final = 1; printf("Erreur semantique a la ligne: %d, la methode '%s' n'existe pas dans la classe %s\n", nb_ligne, $3, nom);}else{sauvType1=$3; ch = nom;nb = getparametre($3,nom);}}}else{if(declared($3, $1)==0){final = 1; printf("Erreur semantique a la ligne: %d, la methode '%s' est non declaree\n", nb_ligne, $3);}else{sauvType1=$3;ch = nom_classe;nb = getparametre($3,nom_classe);}};}
        | IDF           {$$ = $1; num1=1; nom = ""; if(declared($1, nom_classe)==0){final = 1; printf("Erreur semantique a la ligne: %d, la methode '%s' est non declaree\n", nb_ligne, $1);}else{sauvType1=$1; ch = nom_classe; nb = getparametre($1,nom_classe);};}
;

/*============== AFFECTATION =============*/
inst_aff : valeur1 egal  exp  {  initialise=1;
                                 $$=$1.val;
                                 if(strcmp($1.type, $3.type)!=0){printf("Erreur semantique a la ligne: %d, incompatibilite de type, affectation %s de type %s ---> '%s' de type %s\n", nb_ligne, $3.val, $3.type, $1.val, $1.type);}
                                 else if(sauvPriv){      
										         insererQuad("=", $3.val, "", $1.val);
										         tab_niv_quad[ind_niv].num_quad = qc-1;
										         tab_niv_quad[ind_niv].niveau = niv_imbrication;
										         ind_niv++;
                                 }
                                 sauvPriv=1;
                              }
;
egal : '=' | ADDEGAL ; 


/*******************************************************************************************************************************************/
cond : cond AND {empiler(&pile_br_bin_and, qc-1); dans_if=1;} cond    
     | cond OR {
                  if(dans_if==1){
                     int num_quad;
                     char num_quad_courant[10];
                     sprintf(num_quad_courant, "%d", qc+1);

                     while(!pileVide(pile_br_bin_and)){  
                        desempiler(&pile_br_bin_and, &num_quad);
								majQuad(num_quad, 1, num_quad_courant);
							}
                     majQuad(qc-1, 1, num_quad_courant);

                     insererQuad("BR", "", "", "");
                     empiler(&pile_br_bin_or, qc-1); 
                     empiler(&pile_br_bin_or, -1);
                     
                  }
                  else{
                     majCondQuad(qc); 
                     empiler(&pile_br_bin_or, qc-1);
                     empiler(&pile_br_bin_or, -1); 
                  }
                  dans_if=0;
               } cond     
     | NOT cond  {majCondQuad(qc);}    
     | '(' cond ')'    
     | expL           
;

expL  : exp BG exp   {  
                        insererQuad("BLE", "", $1.val, $3.val);
				   			tab_niv_quad[ind_niv].num_quad = qc-1;
								tab_niv_quad[ind_niv].niveau = niv_imbrication;
								ind_niv++;
                     }
      | exp BGE exp  {
                        insererQuad("BL", "", $1.val, $3.val);
				   			tab_niv_quad[ind_niv].num_quad = qc-1;
								tab_niv_quad[ind_niv].niveau = niv_imbrication;
								ind_niv++;
                     }
      | exp BL exp   {
                        insererQuad("BGE", "", $1.val, $3.val);
				   			tab_niv_quad[ind_niv].num_quad = qc-1;
								tab_niv_quad[ind_niv].niveau = niv_imbrication;
								ind_niv++;
                     }
      | exp BLE exp  {
                        insererQuad("BG", "", $1.val, $3.val);
				   			tab_niv_quad[ind_niv].num_quad = qc-1;
								tab_niv_quad[ind_niv].niveau = niv_imbrication;
								ind_niv++;
                     }
      | exp BE exp   {
                        insererQuad("BNE", "", $1.val, $3.val);
                        printf("$1.val = %s    ,    $3.val = %s", $1.val, $3.val);
				   			tab_niv_quad[ind_niv].num_quad = qc-1;
								tab_niv_quad[ind_niv].niveau = niv_imbrication;
								ind_niv++;
                     }
      | exp BNE exp  {
                        insererQuad("BE", "", $1.val, $3.val);
				   			tab_niv_quad[ind_niv].num_quad = qc-1;
								tab_niv_quad[ind_niv].niveau = niv_imbrication;
								ind_niv++;
                     }       
;

exp : exp SUB exp       {
                           $$.type=max($1.type,$3.type); 
                           if(strcmp($1.type, "string")==0 || strcmp($1.type, "char")==0 || strcmp($1.type, "boolean")==0){printf("erreur semantique a la ligne: %d, la valeur a soustraire doit etre un entier, double ou float\n", nb_ligne);}
                           else{
                              sprintf(tmp, "t%d", compteur++);
                              insererQuad("-", $1.val, $3.val, tmp);
                              $$.val=strdup(tmp);
                                                       
                              tab_niv_quad[ind_niv].num_quad = qc-1;
                              tab_niv_quad[ind_niv].niveau = niv_imbrication;
                              ind_niv++;
                           };
                         
                        }
    | exp ADD exp       {
                           $$.type=max($1.type,$3.type); 
                           if(strcmp($1.type, "char")==0 || strcmp($1.type, "boolean")==0){printf("erreur semantique a la ligne: %d, la valeur a additionner doit etre un entier, double ou float\n", nb_ligne);}
                           else{
                              sprintf(tmp, "t%d", compteur++);
                              insererQuad("+", $1.val, $3.val, tmp);
                              $$.val=strdup(tmp);
                                                       
                              tab_niv_quad[ind_niv].num_quad = qc-1;
                              tab_niv_quad[ind_niv].niveau = niv_imbrication;
                              ind_niv++;
                           };
                        }

    | exp MUL exp       {
                           $$.type=max($1.type,$3.type); 
                           if(strcmp($1.type, "string")==0 || strcmp($1.type, "char")==0 || strcmp($1.type, "boolean")==0){printf("erreur semantique a la ligne: %d, la valeur a multiplier etre un entier, double ou float\n", nb_ligne);}
                           else{
                              sprintf(tmp, "t%d", compteur++);
                              insererQuad("*", $1.val, $3.val, tmp);
                              $$.val=strdup(tmp);
                                                       
                              tab_niv_quad[ind_niv].num_quad = qc-1;
                              tab_niv_quad[ind_niv].niveau = niv_imbrication;
                              ind_niv++;
                           };
                        }
    | exp DIV exp       {
                           $$.type=max($1.type,$3.type); 
                           if(strcmp($1.type, "string")==0 || strcmp($1.type, "char")==0 || strcmp($1.type, "boolean")==0){printf("erreur semantique a la ligne: %d, la valeur a diviser doit etre un entier, double ou float\n", nb_ligne);} 
                           else if(atoi($3.val)==0){printf("erreur semantique a la ligne: %d, division par 0 impossible\n",nb_ligne);}
                           else{
                              sprintf(tmp, "t%d", compteur++);
                              insererQuad("/", $1.val, $3.val, tmp);
                              $$.val=strdup(tmp);
                                                       
                              tab_niv_quad[ind_niv].num_quad = qc-1;
                              tab_niv_quad[ind_niv].niveau = niv_imbrication;
                              ind_niv++;
                           };
                        }
    | exp DIVE exp      {
                           $$.type=max($1.type,$3.type); 
                           if(strcmp($1.type, "string")==0 || strcmp($1.type, "char")==0 || strcmp($1.type, "boolean")==0){printf("erreur semantique a la ligne: %d, la valeur a diviser doit etre un entier, double ou float\n", nb_ligne);} 
                           else if(atoi($3.val)==0){printf("erreur semantique a la ligne: %d, division par 0 impossible\n",nb_ligne);}
                           else{
                              sprintf(tmp, "t%d", compteur++);
                              insererQuad("%", $1.val, $3.val, tmp);
                              $$.val=strdup(tmp);
                                                       
                              tab_niv_quad[ind_niv].num_quad = qc-1;
                              tab_niv_quad[ind_niv].niveau = niv_imbrication;
                              ind_niv++;
                           };
                        }
    | '(' exp ')'       {$$.type=$2.type; $$.val=$2.val;}
    | {verif=0;} valeur {$$.type=$2.type; $$.val=$2.val; verif=1;}
;

valeur : ENTIER          {$$.val = $1; $$.type = "int";}
       | REEL_D          {$$.val = $1; $$.type = "double";}
       | REEL_F          {$$.val = $1; $$.type = "float";}
       | STR             {$$.val = $1; $$.type = "string";}
       | CAR             {$$.val = $1; $$.type = "char";}
       | BOOL            {$$.val = $1; $$.type = "boolean";}
       | valeur1         {$$.val = $1.val; $$.type = $1.type;}
       | appel_methode   {$$.val = ""; $$.type = $1.type; if(strcmp($1.type, "void")==0){printf("erreur semantique a la ligne: %d, la methode %s doit avoir un type de retour non void pour l'affecter\n", nb_ligne, $1.val);};}
;

valeur1 : left_value                            {$$.val = $1.val; $$.type = $1.type;}    
        | left_value '['ENTIER']'               {
                                                   char s1[20];
                                                   sprintf(s1, "%s[%s]", $1,$3);
                                                   $$.val = s1; $$.type = $1.type; 
                                                   if(sauvPriv){
                                                      if((nb_tab_ligne==0 && nb_tab_col==0) || nb_tab_ligne>1){printf("Erreur semantique a la ligne: %d, l'attribut '%s' n'est pas un tableau\n", nb_ligne, $1.val); sauvPriv=0;} 
                                                      else if(atoi($3)>nb_tab_col){printf("Erreur semantique a la ligne: %d, depassement de taiile pour le tableau '%s'\n", nb_ligne, $1.val); sauvPriv=0;}
                                                      else if(atoi($3)<0){printf("Erreur semantique a la ligne: %d, tableau '%s': le nombre de lignes ou de colonnes doit >0\n", nb_ligne, $1.val); sauvPriv=0;}
                                                   };
                                                }
        | left_value '['ENTIER']' '['ENTIER']'  {
                                                   char s1[20];
                                                   sprintf(s1, "%s[%s][%s]", $1,$3,$6);
                                                   $$.val = s1; $$.type = $1.type; 
                                                   if(sauvPriv){
                                                      if((nb_tab_ligne==0 && nb_tab_col==0) || nb_tab_ligne==1){printf("Erreur semantique a la ligne: %d, l'attribut '%s' n'est pas une matrice\n", nb_ligne, $1.val); sauvPriv=0;} 
                                                      if(atoi($3)>nb_tab_ligne){printf("Erreur semantique a la ligne: %d, depassement du nombre de lignes pour la matrice '%s'\n", nb_ligne, $1.val); sauvPriv=0;} 
                                                      if(atoi($6)>nb_tab_col){printf("Erreur semantique a la ligne: %d, depassement du nombre de colonnes pour la matrice '%s'\n", nb_ligne, $1.val); sauvPriv=0;} 
                                                      if(atoi($3)<0 || atoi($6)<0 ){printf("Erreur semantique a la ligne: %d, matrice '%s': le nombre de lignes ou de colonnes doit >0\n", nb_ligne, $1.val); sauvPriv=0;}
                                                   };
                                                }
;

left_value : THIS '.' IDF  {  
                              char s1[20];
                              sprintf(s1, "this.%s", $3);
                              $$.val = s1;
   
                              if(declared($3, nom_classe)==1) {
                                 num1 = getsignature(nom_methode, nom_classe); 
                                 $$.type = gettype($3, nom_classe); 
                                 if(getcode($3, "", nom_classe) != 5 && verif){printf("Erreur semantique a la ligne: %d, l'attribut '%s' doit etre une variable pour etre modifiable, pas une constante ou autre\n", nb_ligne, $3); sauvPriv=0;}
                                 else {
                                    if((num1 == 4 || num1 == 41 || num1 == 42 || num1 == 43)&& verif){printf("Erreur semantique a la ligne: %d, impossible d'utiliser l'attribut non static '%s' dans la methode statique '%s'\n", nb_ligne, $3, nom_methode); sauvPriv=0;}
                                    else {nb_tab_ligne = getNbLigne($3, nom_classe); nb_tab_col = getNbCol($3, nom_classe); sauvPriv=1;}
                                 }
                              } 
                              else {
                                 if(declared($3, concat(nom_methode, nom_classe))==1){$$.type = gettype($3, concat(nom_methode, nom_classe)); printf("Erreur semantique a la ligne: %d, pas de 'this', l'attribut '%s' est interne a la methode\n", nb_ligne, $3); sauvPriv=0;}
                                 else{printf("Erreur semantique a la ligne: %d, l'attribut '%s' est non declare\n", nb_ligne, $3); sauvPriv=0;}
                              };
                              num1 = 0;
                           }

           | IDF          {
                              $$.val = $1; 
                              if(declared($1, nom_classe)==1) {
                                 num1 = getsignature(nom_methode, nom_classe); 
                                 $$.type = gettype($1, nom_classe); 
                                 if(getcode($1, "", nom_classe) != 5 && verif){sauvPriv = 0;printf("Erreur semantique a la ligne: %d, l'attribut '%s' doit etre une variable pour etre modifiable, pas une constante ou autre\n", nb_ligne, $1);}
                                 else {
                                    if((num1 == 4 || num1 == 41 || num1 == 42 || num1 == 43) && verif){sauvPriv = 0;printf("Erreur semantique a la ligne: %d, impossible d'utiliser l'attribut non static '%s' dans la methode statique '%s'\n", nb_ligne, $1, nom_methode);}
                                    else{nb_tab_ligne = getNbLigne($1, nom_classe);nb_tab_col = getNbCol($1, nom_classe);}
                                 }
                              }
                              else {
                                 if(declared($1, concat(nom_methode, nom_classe))==0){sauvPriv = 0;printf("Erreur semantique a la ligne: %d, l'attribut '%s' est non declare\n", nb_ligne, $1);}
                                 else {
                                    $$.type = gettype($1, concat(nom_methode, nom_classe));
                                    if(getcode($1, nom_methode, nom_classe) != 5 && verif){sauvPriv = 0;printf("Erreur semantique a la ligne: %d, impossible de modifier la constante '%s'\n", nb_ligne, $1);}
                                    else{
                                       nb_tab_ligne = getNbLigne($1, concat(nom_methode, nom_classe));
                                       nb_tab_col = getNbCol($1, concat(nom_methode, nom_classe));
                                    }
                                 }
                              }; 
                              num1 = 0;
                           }
;


%%

void yyerror(const char *s) {
    printf("Erreur syntaxique {ligne: %d ; colonne: %d}\n", nb_ligne, nb_colonne - str_length);
    /* 
	 afin de savoir exactement ou se trouve l'erreur syntaxique on aura besoin de connetre la taille de l'entite
	 lexicale actuelle (str_lenth), car l'analyseur lexicale va d'abord lire l'entite pour que l'analyseur 
	 syntaxique puisse la comparer avec l'entite qui doit etre presente, si elles sont identiques alors 
	 ce n'est pas une erreur sinon ca l'est, dans ce cas lorsqu'on affiche la colonne ou se trouve 
	 l'erreur on doit pas inclure la taille de la mauvaise entite puisque l'erreur se trouve juste avant. 
 	*/
}


int main(int argc, char **argv) {
   init();
   if (argc > 1) {
      FILE *file = fopen(argv[1], "r");
      if (!file) {
         perror("Could not open file");
         return 1;
      }
      yyin = file;
   }
   printf(" \n=============== Analyse lexico-syntaxique ================\n\n");
   yyparse();
    
   //printf("\n");
   //afficher();

	printf("\n\n=================== Avant optimisation ===================\n");
	afficherQuad();

   optimisation();
	printf("\n\n=================== Apres optimisation ===================\n");
	afficherQuad();
   return 0;
}


