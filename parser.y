%code requires {
#include "symbol_table.h"

typedef struct {
    DataType type;
    char *value;
} Expr;

typedef struct {
    void *elements;
    int size;
    DataType element_type;
    int *row_sizes;
} ArrayInit;
}

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "symbol_table.h"

extern int yylex();
extern int line;
extern int column;

SymbolTable *sym_table;
SymbolTable *meta_table;
QuadList *quad_list;
int has_main = 0;
int main_class_count = 0;
int temp_count = 0;
int label_count = 0;

char *new_temp() {
    char *temp = malloc(10);
    sprintf(temp, "t%d", temp_count++);
    return temp;
}

char *new_label() {
    char *label = malloc(10);
    sprintf(label, "L%d", label_count++);
    return label;
}

void yyerror(const char *s) {
    fprintf(stderr, "Error: %s at line %d, column %d\n", s, line, column);
}

int type_compatible(DataType t1, DataType t2) {
    return t1 == t2 ||
           (t1 == TYPE_DOUBLE && (t2 == TYPE_INT || t2 == TYPE_FLOAT)) ||
           (t1 == TYPE_FLOAT && t2 == TYPE_INT) ||
           (t1 == TYPE_DOUBLE_ARRAY && (t2 == TYPE_INT_ARRAY || t2 == TYPE_FLOAT_ARRAY)) ||
           (t1 == TYPE_FLOAT_ARRAY && t2 == TYPE_INT_ARRAY);
}

void evaluate_expression(DataType *type, char **value, DataType t1, char *v1, char *op, DataType t2, char *v2) {
    Symbol *s1 = v1 ? lookup_symbol(sym_table, v1) : NULL;
    Symbol *s2 = v2 ? lookup_symbol(sym_table, v2) : NULL;
    char *lit1 = s1 ? NULL : v1;
    char *lit2 = s2 ? NULL : v2;

    if (s1 && !s1->is_initialized) yyerror("Use of uninitialized variable");
    if (s2 && !s2->is_initialized) yyerror("Use of uninitialized variable");

    if (strcmp(op, "+") == 0 || strcmp(op, "-") == 0 ||
        strcmp(op, "*") == 0 || strcmp(op, "/") == 0) {
        if (!type_compatible(t1, t2)) yyerror("Type mismatch in arithmetic operation");
        *type = (t1 == TYPE_DOUBLE || t2 == TYPE_DOUBLE) ? TYPE_DOUBLE :
                (t1 == TYPE_FLOAT || t2 == TYPE_FLOAT) ? TYPE_FLOAT : TYPE_INT;

        char *temp = new_temp();
        char result[32];

        if (lit1 && lit2) {
            // Both literals
            if (*type == TYPE_INT) {
                int r = strcmp(op, "+") == 0 ? atoi(lit1) + atoi(lit2) :
                        strcmp(op, "-") == 0 ? atoi(lit1) - atoi(lit2) :
                        strcmp(op, "*") == 0 ? atoi(lit1) * atoi(lit2) :
                        atoi(lit1) / atoi(lit2);
                if (strcmp(op, "/") == 0 && atoi(lit2) == 0) yyerror("Division by zero");
                sprintf(result, "%d", r);
            } else {
                float r = strcmp(op, "+") == 0 ? atof(lit1) + atof(lit2) :
                          strcmp(op, "-") == 0 ? atof(lit1) - atof(lit2) :
                          strcmp(op, "*") == 0 ? atof(lit1) * atof(lit2) :
                          atof(lit1) / atof(lit2);
                if (strcmp(op, "/") == 0 && atof(lit2) == 0.0) yyerror("Division by zero");
                sprintf(result, "%f", r);
            }
            *value = strdup(result);
            add_quad(quad_list, op, v1, v2, temp);
            insert_symbol(sym_table, temp, *type, 0);
            update_symbol_value(sym_table, temp, *type, *value);
            *value = strdup(temp);
        } else if (s1 && lit2) {
            // Variable + literal
            if (*type == TYPE_INT) {
                int val1 = s1->value.i_val;
                int val2 = atoi(lit2);
                int r = strcmp(op, "+") == 0 ? val1 + val2 :
                        strcmp(op, "-") == 0 ? val1 - val2 :
                        strcmp(op, "*") == 0 ? val1 * val2 :
                        val1 / val2;
                if (strcmp(op, "/") == 0 && val2 == 0) yyerror("Division by zero");
                sprintf(result, "%d", r);
            } else {
                float val1 = (*type == TYPE_FLOAT ? s1->value.f_val : s1->value.d_val);
                float val2 = atof(lit2);
                float r = strcmp(op, "+") == 0 ? val1 + val2 :
                          strcmp(op, "-") == 0 ? val1 - val2 :
                          strcmp(op, "*") == 0 ? val1 * val2 :
                          val1 / val2;
                if (strcmp(op, "/") == 0 && val2 == 0.0) yyerror("Division by zero");
                sprintf(result, "%f", r);
            }
            *value = strdup(result);
            add_quad(quad_list, op, v1, v2, temp);
            insert_symbol(sym_table, temp, *type, 0);
            update_symbol_value(sym_table, temp, *type, *value);
            *value = strdup(temp);
        } else if (s1 && s2) {
            // Variable + variable
            if (*type == TYPE_INT) {
                int val1 = s1->value.i_val;
                int val2 = s2->value.i_val;
                int r = strcmp(op, "+") == 0 ? val1 + val2 :
                        strcmp(op, "-") == 0 ? val1 - val2 :
                        strcmp(op, "*") == 0 ? val1 * val2 :
                        val1 / val2;
                if (strcmp(op, "/") == 0 && val2 == 0) yyerror("Division by zero");
                sprintf(result, "%d", r);
            } else {
                float val1 = (*type == TYPE_FLOAT ? s1->value.f_val : s1->value.d_val);
                float val2 = (*type == TYPE_FLOAT ? s2->value.f_val : s2->value.d_val);
                float r = strcmp(op, "+") == 0 ? val1 + val2 :
                          strcmp(op, "-") == 0 ? val1 - val2 :
                          strcmp(op, "*") == 0 ? val1 * val2 :
                          val1 / val2;
                if (strcmp(op, "/") == 0 && val2 == 0.0) yyerror("Division by zero");
                sprintf(result, "%f", r);
            }
            *value = strdup(result);
            add_quad(quad_list, op, v1, v2, temp);
            insert_symbol(sym_table, temp, *type, 0);
            update_symbol_value(sym_table, temp, *type, *value);
            *value = strdup(temp);
        } else {
            // Literal + variable (rare, handle for completeness)
            if (*type == TYPE_INT) {
                int val1 = atoi(lit1);
                int val2 = s2->value.i_val;
                int r = strcmp(op, "+") == 0 ? val1 + val2 :
                        strcmp(op, "-") == 0 ? val1 - val2 :
                        strcmp(op, "*") == 0 ? val1 * val2 :
                        val1 / val2;
                if (strcmp(op, "/") == 0 && val2 == 0) yyerror("Division by zero");
                sprintf(result, "%d", r);
            } else {
                float val1 = atof(lit1);
                float val2 = (*type == TYPE_FLOAT ? s2->value.f_val : s2->value.d_val);
                float r = strcmp(op, "+") == 0 ? val1 + val2 :
                          strcmp(op, "-") == 0 ? val1 - val2 :
                          strcmp(op, "*") == 0 ? val1 * val2 :
                          val1 / val2;
                if (strcmp(op, "/") == 0 && val2 == 0.0) yyerror("Division by zero");
                sprintf(result, "%f", r);
            }
            *value = strdup(result);
            add_quad(quad_list, op, v1, v2, temp);
            insert_symbol(sym_table, temp, *type, 0);
            update_symbol_value(sym_table, temp, *type, *value);
            *value = strdup(temp);
        }
    } else if (strcmp(op, "<") == 0 || strcmp(op, ">") == 0 ||
               strcmp(op, "<=") == 0 || strcmp(op, ">=") == 0 ||
               strcmp(op, "==") == 0 || strcmp(op, "!=") == 0) {
        if (!type_compatible(t1, t2)) yyerror("Type mismatch in comparison");
        *type = TYPE_BOOLEAN;

        char *temp = new_temp();
        if (lit1 && lit2 && !lookup_symbol(sym_table, v1) && !lookup_symbol(sym_table, v2)) {
            int r;
            if (t1 == TYPE_INT && t2 == TYPE_INT) {
                r = strcmp(op, "<") == 0 ? atoi(lit1) < atoi(lit2) :
                    strcmp(op, ">") == 0 ? atoi(lit1) > atoi(lit2) :
                    strcmp(op, "<=") == 0 ? atoi(lit1) <= atoi(lit2) :
                    strcmp(op, ">=") == 0 ? atoi(lit1) >= atoi(lit2) :
                    strcmp(op, "==") == 0 ? atoi(lit1) == atoi(lit2) :
                    atoi(lit1) != atoi(lit2);
            } else {
                float f1 = atof(lit1), f2 = atof(lit2);
                r = strcmp(op, "<") == 0 ? f1 < f2 :
                    strcmp(op, ">") == 0 ? f1 > f2 :
                    strcmp(op, "<=") == 0 ? f1 <= f2 :
                    strcmp(op, ">=") == 0 ? f1 >= f2 :
                    strcmp(op, "==") == 0 ? f1 == f2 :
                    f1 != f2;
            }
            add_quad(quad_list, op, v1, v2, temp);
            *value = strdup(r ? "true" : "false");
            insert_symbol(sym_table, temp, TYPE_BOOLEAN, 0);
            update_symbol_value(sym_table, temp, TYPE_BOOLEAN, *value);
        } else {
            add_quad(quad_list, op, v1, v2, temp);
            insert_symbol(sym_table, temp, TYPE_BOOLEAN, 0);
            // Defer value computation for runtime evaluation
            *value = strdup(temp);
        }
    } else if (strcmp(op, "!") == 0) {
        if (t1 != TYPE_BOOLEAN) yyerror("Logical NOT requires boolean operand");
        *type = TYPE_BOOLEAN;

        char *temp = new_temp();
        if (lit1) {
            int r = strcmp(lit1, "true") == 0 ? 0 : 1;
            add_quad(quad_list, op, lit1, NULL, temp);
            *value = strdup(r ? "true" : "false");
            insert_symbol(sym_table, temp, TYPE_BOOLEAN, 0);
            update_symbol_value(sym_table, temp, TYPE_BOOLEAN, *value);
        } else {
            add_quad(quad_list, op, v1, NULL, temp);
            *value = strdup(temp);
        }
    }
}
%}

%union {
    char *str;
    DataType dtype;
    Expr Expr;
    ArrayInit ArrayInit;
    struct {
        DataType *types;
        char **values;
        int count;
    } arg_list;
    struct {
        char **names;
        Expr *inits;
        ArrayInit *array_inits;
        int count;
    } ident_list;
}

%token INT FLOAT DOUBLE CHAR STRING BOOLEAN FINAL VOID
%token IF ELSE SWITCH CASE DEFAULT DO WHILE FOR TRY CATCH CLASS PUBLIC STATIC BREAK IMPORT
%token <str> INTEGER_LITERAL FLOAT_LITERAL CHAR_LITERAL STRING_LITERAL BOOLEAN_LITERAL
%token <str> IDENTIFIER NEW
%token PLUS MINUS MULTIPLY DIVIDE ASSIGN
%token EQUAL NOT_EQUAL LESS GREATER LESS_EQUAL GREATER_EQUAL NOT
%token LPAREN RPAREN LBRACE RBRACE LBRACKET RBRACKET
%token SEMICOLON COMMA DOT PRINTLN COLON

%type <dtype> type return_type base_type
%type <Expr> expression assignment_expression relational_expression additive_expression multiplicative_expression unary_expression primary_expression literal
%type <ArrayInit> array_initializer array_elements array_2d_elements
%type <str> import_name qualified_name
%type <arg_list> argument_list arguments
%type <ident_list> identifier_list identifier_init

%left EQUAL NOT_EQUAL
%left LESS GREATER LESS_EQUAL GREATER_EQUAL
%left PLUS MINUS
%left MULTIPLY DIVIDE
%right NOT

%%

program: import_statements class_declarations
    {
        if (!has_main || main_class_count != 1) {
            yyerror("Program must contain exactly one public static void main(String[] args) method");
        } else {
            printf("Parsing completed successfully\n");
            print_symbol_table(meta_table);
            print_symbol_table(sym_table);
            print_quads(quad_list);
        }
    }
    ;

import_statements: /* empty */
    | import_statements import_statement
    ;

import_statement: IMPORT import_name SEMICOLON
    {
        if (!insert_symbol(meta_table, $2, TYPE_IMPORT, 0)) {
            yyerror("Duplicate import declaration");
        }
        update_symbol_value(meta_table, $2, TYPE_IMPORT, $2);
    }
    ;

import_name: IDENTIFIER
    { $$ = $1; }
    | import_name DOT IDENTIFIER
    {
        char *new_name = malloc(strlen($1) + strlen($3) + 2);
        sprintf(new_name, "%s.%s", $1, $3);
        free($1);
        $$ = new_name;
    }
    ;

class_declarations: class_declaration
    | class_declarations class_declaration
    ;

class_declaration: CLASS IDENTIFIER LBRACE class_body RBRACE
    {
        if (!insert_symbol(meta_table, $2, TYPE_CLASS, 0)) {
            yyerror("Duplicate class declaration");
        }
        update_symbol_value(meta_table, $2, TYPE_CLASS, $2);
    }
    ;

class_body: /* empty */
    | class_body declaration
    ;

declaration: variable_declaration SEMICOLON
    | method_declaration
    ;

variable_declaration: type identifier_list
    {
        for (int i = 0; i < $2.count; i++) {
            if (!insert_symbol(sym_table, $2.names[i], $1, 0)) {
                yyerror("Duplicate variable declaration");
            }
            if ($2.inits[i].type != TYPE_VOID) {
                if ($1 != $2.inits[i].type) {
                    yyerror("Type mismatch in variable initialization");
                }
                if ($2.inits[i].value) {
                    update_symbol_value(sym_table, $2.names[i], $1, $2.inits[i].value);
                    add_quad(quad_list, "=", $2.inits[i].value, NULL, $2.names[i]);
                }
            } else if ($2.array_inits[i].elements) {
                DataType expected_type = $1;
                DataType base_type = $2.array_inits[i].element_type;
                if ($1 >= TYPE_INT_ARRAY_2D && $1 <= TYPE_BOOLEAN_ARRAY_2D) {
                    expected_type = base_type + (TYPE_INT_ARRAY_2D - TYPE_INT);
                } else if ($1 >= TYPE_INT_ARRAY && $1 <= TYPE_BOOLEAN_ARRAY) {
                    expected_type = base_type + (TYPE_INT_ARRAY - TYPE_INT);
                } else {
                    yyerror("Array initialization not allowed for scalar type");
                }
                if ($1 != expected_type) {
                    yyerror("Array type mismatch in initialization");
                }
                update_array_value(sym_table, $2.names[i], $1, $2.array_inits[i].elements, $2.array_inits[i].size, $2.array_inits[i].row_sizes);
                char *temp = new_temp();
                add_quad(quad_list, "array_init", NULL, NULL, temp);
                add_quad(quad_list, "=", temp, NULL, $2.names[i]);
                if ($1 == TYPE_STRING_ARRAY || $1 == TYPE_STRING_ARRAY_2D) {
                    if ($1 == TYPE_STRING_ARRAY) {
                        for (int j = 0; j < $2.array_inits[i].size; j++) free(((char **)$2.array_inits[i].elements)[j]);
                    } else {
                        for (int j = 0; j < $2.array_inits[i].size; j++) {
                            for (int k = 0; k < $2.array_inits[i].row_sizes[j]; k++) free(((char ***) $2.array_inits[i].elements)[j][k]);
                            free(((char ***) $2.array_inits[i].elements)[j]);
                        }
                    }
                }
                free($2.array_inits[i].elements);
                if ($2.array_inits[i].row_sizes) free($2.array_inits[i].row_sizes);
            } else if ($2.array_inits[i].size > 0 && $2.array_inits[i].elements == NULL) {
                if ($1 != $2.array_inits[i].element_type) {
                    yyerror("Invalid array type for new allocation");
                }
                Symbol *sym = lookup_symbol(sym_table, $2.names[i]);
                if (!sym) yyerror("Symbol not found after insertion");
                sym->dimensions.rows = $2.array_inits[i].size;
                if ($1 >= TYPE_INT_ARRAY_2D && $1 <= TYPE_BOOLEAN_ARRAY_2D) {
                    if (!$2.array_inits[i].row_sizes) yyerror("Missing column size for 2D array");
                    sym->dimensions.cols = $2.array_inits[i].row_sizes[0];
                    update_static_array(sym_table, $2.names[i], $1, NULL, sym->dimensions.rows, sym->dimensions.cols);
                    char *temp = new_temp();
                    char rows[16], cols[16];
                    sprintf(rows, "%d", $2.array_inits[i].size);
                    sprintf(cols, "%d", $2.array_inits[i].row_sizes[0]);
                    add_quad(quad_list, "array_init_static", rows, cols, temp);
                    add_quad(quad_list, "=", temp, NULL, $2.names[i]);
                    free($2.array_inits[i].row_sizes);
                } else if ($1 >= TYPE_INT_ARRAY && $1 <= TYPE_BOOLEAN_ARRAY) {
                    update_static_array_1d(sym_table, $2.names[i], $1, NULL, sym->dimensions.rows);
                    char *temp = new_temp();
                    char size[16];
                    sprintf(size, "%d", $2.array_inits[i].size);
                    add_quad(quad_list, "array_init_static", size, NULL, temp);
                    add_quad(quad_list, "=", temp, NULL, $2.names[i]);
                    printf("Allocated 1D array %s with size %d\n", $2.names[i], $2.array_inits[i].size);
                } else {
                    yyerror("Invalid type for new array allocation");
                }
            }
        }
        for (int i = 0; i < $2.count; i++) free($2.names[i]);
        free($2.names);
        free($2.inits);
        free($2.array_inits);
    }
    | FINAL type identifier_list
    {
        for (int i = 0; i < $3.count; i++) {
            if ($3.inits[i].type == TYPE_VOID && $3.array_inits[i].elements == NULL && $3.array_inits[i].size == 0) {
                yyerror("Final variable must be initialized");
            }
            if (!insert_symbol(sym_table, $3.names[i], $2, 1)) {
                yyerror("Duplicate constant declaration");
            }
            if ($3.inits[i].type != TYPE_VOID) {
                if ($2 != $3.inits[i].type) {
                    yyerror("Type mismatch in final variable initialization");
                }
                if ($3.inits[i].value) {
                    update_symbol_value(sym_table, $3.names[i], $2, $3.inits[i].value);
                    add_quad(quad_list, "=", $3.inits[i].value, NULL, $3.names[i]);
                }
            } else if ($3.array_inits[i].elements) {
                DataType expected_type = $2;
                DataType base_type = $3.array_inits[i].element_type;
                if ($2 >= TYPE_INT_ARRAY_2D && $2 <= TYPE_BOOLEAN_ARRAY_2D) {
                    expected_type = base_type + (TYPE_INT_ARRAY_2D - TYPE_INT);
                } else if ($2 >= TYPE_INT_ARRAY && $2 <= TYPE_BOOLEAN_ARRAY) {
                    expected_type = base_type + (TYPE_INT_ARRAY - TYPE_INT);
                } else {
                    yyerror("Array initialization not allowed for scalar type");
                }
                if ($2 != expected_type) {
                    yyerror("Array type mismatch in initialization");
                }
                update_array_value(sym_table, $3.names[i], $2, $3.array_inits[i].elements, $3.array_inits[i].size, $3.array_inits[i].row_sizes);
                char *temp = new_temp();
                add_quad(quad_list, "array_init", NULL, NULL, temp);
                add_quad(quad_list, "=", temp, NULL, $3.names[i]);
                if ($2 == TYPE_STRING_ARRAY || $2 == TYPE_STRING_ARRAY_2D) {
                    if ($2 == TYPE_STRING_ARRAY) {
                        for (int j = 0; j < $3.array_inits[i].size; j++) free(((char **)$3.array_inits[i].elements)[j]);
                    } else {
                        for (int j = 0; j < $3.array_inits[i].size; j++) {
                            for (int k = 0; k < $3.array_inits[i].row_sizes[j]; k++) free(((char ***) $3.array_inits[i].elements)[j][k]);
                            free(((char ***) $3.array_inits[i].elements)[j]);
                        }
                    }
                }
                free($3.array_inits[i].elements);
                if ($3.array_inits[i].row_sizes) free($3.array_inits[i].row_sizes);
            } else if ($3.array_inits[i].size > 0 && $3.array_inits[i].elements == NULL) {
                if ($2 != $3.array_inits[i].element_type) {
                    yyerror("Invalid array type for new allocation");
                }
                Symbol *sym = lookup_symbol(sym_table, $3.names[i]);
                if (!sym) yyerror("Symbol not found after insertion");
                sym->dimensions.rows = $3.array_inits[i].size;
                if ($2 >= TYPE_INT_ARRAY_2D && $2 <= TYPE_BOOLEAN_ARRAY_2D) {
                    if (!$3.array_inits[i].row_sizes) yyerror("Missing column size for 2D array");
                    sym->dimensions.cols = $3.array_inits[i].row_sizes[0];
                    update_static_array(sym_table, $3.names[i], $2, NULL, sym->dimensions.rows, sym->dimensions.cols);
                    char *temp = new_temp();
                    char rows[16], cols[16];
                    sprintf(rows, "%d", $3.array_inits[i].size);
                    sprintf(cols, "%d", $3.array_inits[i].row_sizes[0]);
                    add_quad(quad_list, "array_init_static", rows, cols, temp);
                    add_quad(quad_list, "=", temp, NULL, $3.names[i]);
                    free($3.array_inits[i].row_sizes);
                } else if ($2 >= TYPE_INT_ARRAY && $2 <= TYPE_BOOLEAN_ARRAY) {
                    update_static_array_1d(sym_table, $3.names[i], $2, NULL, sym->dimensions.rows);
                    char *temp = new_temp();
                    char size[16];
                    sprintf(size, "%d", $3.array_inits[i].size);
                    add_quad(quad_list, "array_init_static", size, NULL, temp);
                    add_quad(quad_list, "=", temp, NULL, $3.names[i]);
                    printf("Allocated 1D array %s with size %d\n", $3.names[i], $3.array_inits[i].size);
                } else {
                    yyerror("Invalid type for new array allocation");
                }
            }
        }
        for (int i = 0; i < $3.count; i++) free($3.names[i]);
        free($3.names);
        free($3.inits);
        free($3.array_inits);
    }
    ;

base_type: INT { $$ = TYPE_INT; }
         | FLOAT { $$ = TYPE_FLOAT; }
         | DOUBLE { $$ = TYPE_DOUBLE; }
         | CHAR { $$ = TYPE_CHAR; }
         | STRING { $$ = TYPE_STRING; }
         | BOOLEAN { $$ = TYPE_BOOLEAN; }
         ;

type: base_type { $$ = $1; }
    | base_type LBRACKET RBRACKET
    {
        switch ($1) {
            case TYPE_INT: $$ = TYPE_INT_ARRAY; break;
            case TYPE_FLOAT: $$ = TYPE_FLOAT_ARRAY; break;
            case TYPE_DOUBLE: $$ = TYPE_DOUBLE_ARRAY; break;
            case TYPE_CHAR: $$ = TYPE_CHAR_ARRAY; break;
            case TYPE_STRING: $$ = TYPE_STRING_ARRAY; break;
            case TYPE_BOOLEAN: $$ = TYPE_BOOLEAN_ARRAY; break;
            default: yyerror("Invalid array type");
        }
    }
    | base_type LBRACKET RBRACKET LBRACKET RBRACKET
    {
        switch ($1) {
            case TYPE_INT: $$ = TYPE_INT_ARRAY_2D; break;
            case TYPE_FLOAT: $$ = TYPE_FLOAT_ARRAY_2D; break;
            case TYPE_DOUBLE: $$ = TYPE_DOUBLE_ARRAY_2D; break;
            case TYPE_CHAR: $$ = TYPE_CHAR_ARRAY_2D; break;
            case TYPE_STRING: $$ = TYPE_STRING_ARRAY_2D; break;
            case TYPE_BOOLEAN: $$ = TYPE_BOOLEAN_ARRAY_2D; break;
            default: yyerror("Invalid array type");
        }
    }
    ;

identifier_init: IDENTIFIER
    {
        $$.names = malloc(sizeof(char *));
        $$.inits = malloc(sizeof(Expr));
        $$.array_inits = malloc(sizeof(ArrayInit));
        $$.names[0] = strdup($1);
        $$.inits[0].type = TYPE_VOID;
        $$.inits[0].value = NULL;
        $$.array_inits[0].elements = NULL;
        $$.array_inits[0].size = 0;
        $$.array_inits[0].element_type = TYPE_VOID;
        $$.array_inits[0].row_sizes = NULL;
        $$.count = 1;
    }
    | IDENTIFIER ASSIGN expression
    {
        $$.names = malloc(sizeof(char *));
        $$.inits = malloc(sizeof(Expr));
        $$.array_inits = malloc(sizeof(ArrayInit));
        $$.names[0] = strdup($1);
        $$.inits[0] = $3;
        $$.array_inits[0].elements = NULL;
        $$.array_inits[0].size = 0;
        $$.array_inits[0].element_type = TYPE_VOID;
        $$.array_inits[0].row_sizes = NULL;
        $$.count = 1;
    }
    | IDENTIFIER ASSIGN array_initializer
    {
        $$.names = malloc(sizeof(char *));
        $$.inits = malloc(sizeof(Expr));
        $$.array_inits = malloc(sizeof(ArrayInit));
        $$.names[0] = strdup($1);
        $$.inits[0].type = TYPE_VOID;
        $$.inits[0].value = NULL;
        $$.array_inits[0] = $3;
        $$.count = 1;
    }
    | IDENTIFIER ASSIGN NEW type LBRACKET INTEGER_LITERAL RBRACKET
    {
        int size = atoi($6);
        if (size <= 0) yyerror("Array size must be positive");
        $$.names = malloc(sizeof(char *));
        $$.inits = malloc(sizeof(Expr));
        $$.array_inits = malloc(sizeof(ArrayInit));
        $$.names[0] = strdup($1);
        $$.inits[0].type = TYPE_VOID;
        $$.inits[0].value = NULL;
        $$.array_inits[0].elements = NULL;
        $$.array_inits[0].size = size;
        $$.array_inits[0].element_type = $4;
        $$.array_inits[0].row_sizes = NULL;
        $$.count = 1;
    }
    | IDENTIFIER ASSIGN NEW type LBRACKET INTEGER_LITERAL RBRACKET LBRACKET INTEGER_LITERAL RBRACKET
    {
        int size = atoi($6);
        if (size <= 0) yyerror("Array size must be positive");
        $$.names = malloc(sizeof(char *));
        $$.inits = malloc(sizeof(Expr));
        $$.array_inits = malloc(sizeof(ArrayInit));
        $$.names[0] = strdup($1);
        $$.inits[0].type = TYPE_VOID;
        $$.inits[0].value = NULL;
        $$.array_inits[0].elements = NULL;
        $$.array_inits[0].size = size;
        $$.array_inits[0].element_type = $4;
        $$.array_inits[0].row_sizes = malloc(sizeof(int));
        $$.array_inits[0].row_sizes[0] = atoi($9);
        $$.count = 1;
    }
    ;

identifier_list: identifier_init
    {
        $$ = $1;
    }
    | identifier_list COMMA identifier_init
    {
        $$.names = realloc($1.names, ($1.count + $3.count) * sizeof(char *));
        $$.inits = realloc($1.inits, ($1.count + $3.count) * sizeof(Expr));
        $$.array_inits = realloc($1.array_inits, ($1.count + $3.count) * sizeof(ArrayInit));
        for (int i = 0; i < $3.count; i++) {
            $$.names[$1.count + i] = $3.names[i];
            $$.inits[$1.count + i] = $3.inits[i];
            $$.array_inits[$1.count + i] = $3.array_inits[i];
        }
        $$.count = $1.count + $3.count;
        free($3.names);
        free($3.inits);
        free($3.array_inits);
    }
    ;

return_type: type
    { $$ = $1; }
    | VOID
    { $$ = TYPE_VOID; }
    ;

method_declaration: PUBLIC STATIC VOID IDENTIFIER LPAREN type IDENTIFIER RPAREN block
    {
        DataType param_types[] = {$6};
        if (strcmp($4, "main") == 0) {
            if ($6 != TYPE_STRING_ARRAY || strcmp($7, "args") != 0) {
                yyerror("Main method must be public static void main(String[] args)");
            }
            has_main = 1;
            main_class_count++;
            if (!insert_symbol(sym_table, $7, $6, 0)) {
                yyerror("Duplicate parameter declaration in main");
            }
        }
        if (!insert_method(meta_table, $4, TYPE_VOID, param_types, 1)) {
            yyerror("Duplicate method declaration");
        }
    }
    | return_type IDENTIFIER LPAREN parameter_list RPAREN block
    {
        DataType param_types[10];
        int param_count = 0;
        if (strcmp($2, "main") == 0) {
            yyerror("Main method must be public static void main(String[] args)");
        }
        if (!insert_method(meta_table, $2, $1, param_types, param_count)) {
            yyerror("Duplicate method declaration");
        }
    }
    ;

parameter_list: /* empty */
    | parameters
    ;

parameters: parameter
    | parameters COMMA parameter
    ;

parameter: type IDENTIFIER
    {
        if (!insert_symbol(sym_table, $2, $1, 0)) {
            yyerror("Duplicate parameter declaration");
        }
    }
    ;

block: LBRACE statement_list RBRACE
    ;

statement_list: /* empty */
    | statement_list statement
    ;

statement: variable_declaration SEMICOLON
    | expression SEMICOLON
    | PRINTLN LPAREN expression RPAREN SEMICOLON
    {
        if ($3.value) {
            add_quad(quad_list, "print", $3.value, NULL, NULL);
        }
    }
    | qualified_name DOT PRINTLN LPAREN expression RPAREN SEMICOLON
    {
        if (strcmp($1, "System.out") != 0) {
            yyerror("Only System.out.println is supported");
        }
        if ($5.value) {
            add_quad(quad_list, "print", $5.value, NULL, NULL);
        }
        free($1);
    }
    | if_statement
    | switch_statement
    | while_statement
    | do_while_statement
    | for_statement
    | try_catch_statement
    | block
    ;

qualified_name: IDENTIFIER
    { $$ = strdup($1); }
    | qualified_name DOT IDENTIFIER
    {
        char *new_name = malloc(strlen($1) + strlen($3) + 2);
        sprintf(new_name, "%s.%s", $1, $3);
        free($1);
        free($3);
        $$ = new_name;
    }
    ;

if_statement: IF LPAREN expression RPAREN statement
    {
        if ($3.type != TYPE_BOOLEAN) {
            yyerror("If condition must be boolean");
        }
        char *end_label = new_label();
        add_quad(quad_list, "if_false", $3.value, end_label, NULL);
        add_quad(quad_list, "label", end_label, NULL, NULL);
        free(end_label);
    }
    | IF LPAREN expression RPAREN statement ELSE statement
    {
        if ($3.type != TYPE_BOOLEAN) {
            yyerror("If condition must be boolean");
        }
        char *else_label = new_label();
        char *end_label = new_label();
        add_quad(quad_list, "if_false", $3.value, else_label, NULL);
        add_quad(quad_list, "goto", end_label, NULL, NULL);
        add_quad(quad_list, "label", else_label, NULL, NULL);
        add_quad(quad_list, "label", end_label, NULL, NULL);
        free(else_label);
        free(end_label);
    }
    ;

switch_statement: SWITCH LPAREN expression RPAREN LBRACE case_block_list default_block RBRACE
    ;

case_block_list: /* empty */
    | case_block_list case_block
    ;

case_block: CASE expression COLON statement_list BREAK SEMICOLON
    ;

default_block: /* empty */
    | DEFAULT COLON statement_list BREAK SEMICOLON
    ;

while_statement: WHILE LPAREN expression RPAREN statement
    {
        if ($3.type != TYPE_BOOLEAN) {
            yyerror("While condition must be boolean");
        }
        char *start_label = new_label();
        char *end_label = new_label();
        add_quad(quad_list, "label", start_label, NULL, NULL);
        add_quad(quad_list, "if_false", $3.value, end_label, NULL);
        add_quad(quad_list, "goto", start_label, NULL, NULL);
        add_quad(quad_list, "label", end_label, NULL, NULL);
        free(start_label);
        free(end_label);
    }
    ;

do_while_statement: DO statement WHILE LPAREN expression RPAREN SEMICOLON
    {
        if ($5.type != TYPE_BOOLEAN) {
            yyerror("Do-while condition must be boolean");
        }
        char *start_label = new_label();
        add_quad(quad_list, "label", start_label, NULL, NULL);
        add_quad(quad_list, "if_true", $5.value, start_label, NULL);
        free(start_label);
    }
    ;

for_statement: FOR LPAREN for_init SEMICOLON expression SEMICOLON for_update RPAREN statement
    {
        if ($5.type != TYPE_BOOLEAN) {
            yyerror("For condition must be boolean");
        }
        char *start_label = new_label();
        char *body_label = new_label();
        char *update_label = new_label();
        char *end_label = new_label();
        add_quad(quad_list, "label", start_label, NULL, NULL);
        add_quad(quad_list, "if_false", $5.value, end_label, NULL);
        add_quad(quad_list, "goto", body_label, NULL, NULL);
        add_quad(quad_list, "label", update_label, NULL, NULL);
        // Insert for_update quads here
        add_quad(quad_list, "goto", start_label, NULL, NULL);
        add_quad(quad_list, "label", body_label, NULL, NULL);
        add_quad(quad_list, "goto", update_label, NULL, NULL);
        add_quad(quad_list, "label", end_label, NULL, NULL);
        free(start_label);
        free(body_label);
        free(update_label);
        free(end_label);
    }
    ;

for_init: variable_declaration
    | expression
    {
        if ($1.value) {
            add_quad(quad_list, "=", $1.value, NULL, NULL);
        }
    }
    | /* empty */
    ;

for_update: expression
    {
        if ($1.value) {
            Symbol *sym = lookup_symbol(sym_table, $1.value);
            if (sym) {
                update_symbol_value(sym_table, $1.value, sym->type, $1.value);
                add_quad(quad_list, "=", $1.value, NULL, $1.value);
            }
        }
    }
    | /* empty */
    ;

try_catch_statement: TRY block catch_clause_list
    ;

catch_clause_list: catch_clause
    | catch_clause_list catch_clause
    ;

catch_clause: CATCH LPAREN parameter RPAREN block
    ;

expression: assignment_expression
    { $$ = $1; }
    ;

assignment_expression: IDENTIFIER ASSIGN expression
    {
        Symbol *sym = lookup_symbol(sym_table, $1);
        if (!sym) {
            yyerror("Undeclared variable");
        } else if (sym->is_final) {
            yyerror("Cannot assign to final variable");
        } else if (!type_compatible(sym->type, $3.type)) {
            yyerror("Type mismatch in assignment");
        }
        if ($3.value) {
            char *value = $3.value;
            Symbol *src = lookup_symbol(sym_table, $3.value); // Check if $3.value is a variable/temporary
            if (src && src->is_initialized) {
                // $3.value is a variable or temporary (e.g., t4)
                char buffer[32];
                switch (src->type) {
                    case TYPE_INT:
                        snprintf(buffer, sizeof(buffer), "%d", src->value.i_val);
                        value = strdup(buffer);
                        break;
                    case TYPE_FLOAT:
                        snprintf(buffer, sizeof(buffer), "%f", src->value.f_val);
                        value = strdup(buffer);
                        break;
                    case TYPE_DOUBLE:
                        snprintf(buffer, sizeof(buffer), "%f", src->value.d_val);
                        value = strdup(buffer);
                        break;
                    case TYPE_CHAR:
                        snprintf(buffer, sizeof(buffer), "'%c'", src->value.c_val);
                        value = strdup(buffer);
                        break;
                    case TYPE_STRING:
                    case TYPE_IMPORT:
                    case TYPE_CLASS:
                        value = src->value.s_val ? strdup(src->value.s_val) : strdup("");
                        break;
                    case TYPE_BOOLEAN:
                        value = strdup(src->value.b_val ? "true" : "false");
                        break;
                    default:
                        yyerror("Unsupported type for assignment");
                        value = $3.value;
                }
                printf("Assigning %s to %s (src value: %s)\n", value, $1, $3.value); // Debug
            } else if (!src) {
                // $3.value is a literal
                value = $3.value;
                printf("Assigning literal %s to %s\n", value, $1); // Debug
            } else {
                yyerror("Use of uninitialized variable");
                value = $3.value; // Fallback
            }
            if (!update_symbol_value(sym_table, $1, sym->type, value)) {
                yyerror("Failed to update symbol value");
            }
            add_quad(quad_list, "=", $3.value, NULL, $1);
            sym->is_initialized = 1;
            if (value != $3.value) free(value);
        } else {
            yyerror("Expression has no value");
        }
        $$.type = sym->type;
        $$.value = strdup($1);
    }
    | IDENTIFIER ASSIGN array_initializer
    {
        Symbol *sym = lookup_symbol(sym_table, $1);
        if (!sym) {
            yyerror("Undeclared variable");
        } else if (sym->is_final) {
            yyerror("Cannot assign to final variable");
        }
        DataType expected_type = sym->type;
        DataType base_type = $3.element_type;
        if (sym->type >= TYPE_INT_ARRAY_2D && sym->type <= TYPE_BOOLEAN_ARRAY_2D) {
            expected_type = base_type + (TYPE_INT_ARRAY_2D - TYPE_INT);
        } else if (sym->type >= TYPE_INT_ARRAY && sym->type <= TYPE_BOOLEAN_ARRAY) {
            expected_type = base_type + (TYPE_INT_ARRAY - TYPE_INT);
        } else {
            yyerror("Array initialization not allowed for scalar type");
        }
        if (sym->type != expected_type) {
            yyerror("Array type mismatch in assignment");
        }
        update_array_value(sym_table, $1, sym->type, $3.elements, $3.size, $3.row_sizes);
        char *temp = new_temp();
        add_quad(quad_list, "array_init", NULL, NULL, temp);
        add_quad(quad_list, "=", temp, NULL, $1);
        if (sym->type == TYPE_STRING_ARRAY || sym->type == TYPE_STRING_ARRAY_2D) {
            if (sym->type == TYPE_STRING_ARRAY) {
                for (int i = 0; i < $3.size; i++) free(((char **)$3.elements)[i]);
            } else {
                for (int i = 0; i < $3.size; i++) {
                    for (int j = 0; j < $3.row_sizes[i]; j++) free(((char ***) $3.elements)[i][j]);
                    free(((char ***) $3.elements)[i]);
                }
            }
        }
        free($3.elements);
        if ($3.row_sizes) free($3.row_sizes);
        $$.type = sym->type;
        $$.value = NULL;
    }
    | relational_expression
    { $$ = $1; }
    ;

relational_expression: additive_expression
    { $$ = $1; }
    | relational_expression LESS additive_expression
    {
        evaluate_expression(&$$.type, &$$.value, $1.type, $1.value, "<", $3.type, $3.value);
    }
    | relational_expression GREATER additive_expression
    {
        evaluate_expression(&$$.type, &$$.value, $1.type, $1.value, ">", $3.type, $3.value);
    }
    | relational_expression LESS_EQUAL additive_expression
    {
        evaluate_expression(&$$.type, &$$.value, $1.type, $1.value, "<=", $3.type, $3.value);
    }
    | relational_expression GREATER_EQUAL additive_expression
    {
        evaluate_expression(&$$.type, &$$.value, $1.type, $1.value, ">=", $3.type, $3.value);
    }
    | relational_expression EQUAL additive_expression
    {
        evaluate_expression(&$$.type, &$$.value, $1.type, $1.value, "==", $3.type, $3.value);
    }
    | relational_expression NOT_EQUAL additive_expression
    {
        evaluate_expression(&$$.type, &$$.value, $1.type, $1.value, "!=", $3.type, $3.value);
    }
    ;

additive_expression: multiplicative_expression
    { $$ = $1; }
    | additive_expression PLUS multiplicative_expression
    {
        evaluate_expression(&$$.type, &$$.value, $1.type, $1.value, "+", $3.type, $3.value);
    }
    | additive_expression MINUS multiplicative_expression
    {
        evaluate_expression(&$$.type, &$$.value, $1.type, $1.value, "-", $3.type, $3.value);
    }
    ;

multiplicative_expression: unary_expression
    { $$ = $1; }
    | multiplicative_expression MULTIPLY unary_expression
    {
        evaluate_expression(&$$.type, &$$.value, $1.type, $1.value, "*", $3.type, $3.value);
    }
    | multiplicative_expression DIVIDE unary_expression
    {
        evaluate_expression(&$$.type, &$$.value, $1.type, $1.value, "/", $3.type, $3.value);
        if (!$$.value) {
            printf("Warning: Potential division by zero at line %d, column %d\n", line, column);
        }
    }
    ;

unary_expression: primary_expression
    { $$ = $1; }
    | NOT unary_expression
    {
        evaluate_expression(&$$.type, &$$.value, $2.type, $2.value, "!", TYPE_INT, NULL);
    }
    ;

primary_expression: IDENTIFIER
    {
        Symbol *sym = lookup_symbol(sym_table, $1);
        if (!sym) {
            yyerror("Undeclared variable");
        } else if (!sym->is_initialized) {
            yyerror("Use of uninitialized variable");
        }
        $$.type = sym->type;
        $$.value = strdup($1);
    }
    | IDENTIFIER LBRACKET expression RBRACKET
    {
        Symbol *sym = lookup_symbol(sym_table, $1);
        if (!sym) {
            yyerror("Undeclared variable");
        } else if (sym->type < TYPE_INT_ARRAY || sym->type > TYPE_BOOLEAN_ARRAY_2D) {
            yyerror("Indexing not supported for this type");
        } else if ($3.type != TYPE_INT) {
            yyerror("Array index must be an integer");
        }
        DataType base_type = (sym->type >= TYPE_INT_ARRAY_2D) ? sym->type - (TYPE_INT_ARRAY_2D - TYPE_INT) : sym->type - (TYPE_INT_ARRAY - TYPE_INT);
        $$.type = base_type;
        if ($3.value && strcmp($3.value, "0") >= 0) {
            int index = atoi($3.value);
            if (sym->type >= TYPE_INT_ARRAY && sym->type <= TYPE_BOOLEAN_ARRAY) {
                if (!get_array_element(sym_table, $1, index, -1, &$$.type, &$$.value)) {
                    yyerror("Invalid array index");
                }
            }
            char *temp = new_temp();
            add_quad(quad_list, sym->type >= TYPE_INT_ARRAY_2D ? "array_get_2d_row" : "array_get", $1, $3.value, temp);
            $$.value = strdup(temp);
        } else {
            char *temp = new_temp();
            add_quad(quad_list, sym->type >= TYPE_INT_ARRAY_2D ? "array_get_2d_row" : "array_get", $1, $3.value ? $3.value : "unknown", temp);
            $$.value = strdup(temp);
        }
    }
    | IDENTIFIER LBRACKET expression RBRACKET LBRACKET expression RBRACKET
    {
        Symbol *sym = lookup_symbol(sym_table, $1);
        if (!sym) {
            yyerror("Undeclared variable");
        } else if (sym->type < TYPE_INT_ARRAY_2D || sym->type > TYPE_BOOLEAN_ARRAY_2D) {
            yyerror("Double indexing only supported for 2D arrays");
        } else if ($3.type != TYPE_INT || $6.type != TYPE_INT) {
            yyerror("Array indices must be integers");
        }
        $$.type = sym->type - (TYPE_INT_ARRAY_2D - TYPE_INT);
        char *temp = new_temp();
        char *index_str = malloc(40);
        sprintf(index_str, "%s,%s", $3.value ? $3.value : "unknown", $6.value ? $6.value : "unknown");
        add_quad(quad_list, "array_get_2d", $1, index_str, temp);
        $$.value = strdup(temp);
        if ($3.value && $6.value && strcmp($3.value, "0") >= 0 && strcmp($6.value, "0") >= 0) {
            int index1 = atoi($3.value);
            int index2 = atoi($6.value);
            if (!get_array_element(sym_table, $1, index1, index2, &$$.type, &$$.value)) {
                yyerror("Invalid array index");
            }
        }
    }
    | IDENTIFIER LPAREN argument_list RPAREN
    {
        Symbol *sym = lookup_symbol(meta_table, $1);
        if (!sym || sym->type != TYPE_METHOD) {
            yyerror("Undeclared method");
        }
        if (sym->value.method.params.count != $3.count) {
            yyerror("Incorrect number of arguments in method call");
        }
        for (int i = 0; i < $3.count; i++) {
            if (!type_compatible(sym->value.method.params.types[i], $3.types[i])) {
                yyerror("Type mismatch in method argument");
            }
        }
        $$.type = sym->value.method.return_type;
        char *temp = new_temp();
        char *arg_str = malloc(256);
        arg_str[0] = '\0';
        for (int i = 0; i < $3.count; i++) {
            strcat(arg_str, $3.values[i]);
            if (i < $3.count - 1) strcat(arg_str, ",");
        }
        add_quad(quad_list, "call", $1, arg_str, temp);
        $$.value = strdup(temp);
        free(arg_str);
        free($3.types);
        for (int i = 0; i < $3.count; i++) free($3.values[i]);
        free($3.values);
    }
    | literal
    { $$ = $1; }
    | LPAREN expression RPAREN
    { $$ = $2; }
    ;

literal: INTEGER_LITERAL
    { $$.type = TYPE_INT; $$.value = $1; }
    | FLOAT_LITERAL
    { $$.type = TYPE_FLOAT; $$.value = $1; }
    | CHAR_LITERAL
    { $$.type = TYPE_CHAR; $$.value = $1; }
    | STRING_LITERAL
    { $$.type = TYPE_STRING; $$.value = $1; }
    | BOOLEAN_LITERAL
    { $$.type = TYPE_BOOLEAN; $$.value = $1; }
    ;

argument_list: /* empty */
    {
        $$.count = 0;
        $$.types = NULL;
        $$.values = NULL;
    }
    | arguments
    { $$ = $1; }
    ;

arguments: expression
    {
        $$.count = 1;
        $$.types = malloc(sizeof(DataType));
        $$.types[0] = $1.type;
        $$.values = malloc(sizeof(char *));
        $$.values[0] = $1.value ? strdup($1.value) : NULL;
    }
    | arguments COMMA expression
    {
        $$.count = $1.count + 1;
        $$.types = realloc($1.types, $$.count * sizeof(DataType));
        $$.types[$$.count - 1] = $3.type;
        $$.values = realloc($1.values, $$.count * sizeof(char *));
        $$.values[$$.count - 1] = $3.value ? strdup($3.value) : NULL;
    }
    ;

array_initializer: LBRACE array_elements RBRACE
    {
        $$.elements = $2.elements;
        $$.size = $2.size;
        $$.element_type = $2.element_type;
        $$.row_sizes = NULL;
    }
    | LBRACE array_2d_elements RBRACE
    {
        $$.elements = $2.elements;
        $$.size = $2.size;
        $$.element_type = $2.element_type;
        $$.row_sizes = $2.row_sizes;
    }
    ;

array_elements: expression
    {
        $$.size = 1;
        $$.element_type = $1.type;
        $$.row_sizes = NULL;
        switch ($1.type) {
            case TYPE_INT:
                $$.elements = malloc(sizeof(int));
                ((int *)$$.elements)[0] = $1.value ? atoi($1.value) : 0;
                break;
            case TYPE_FLOAT:
                $$.elements = malloc(sizeof(float));
                ((float *)$$.elements)[0] = $1.value ? atof($1.value) : 0.0;
                break;
            case TYPE_DOUBLE:
                $$.elements = malloc(sizeof(double));
                ((double *)$$.elements)[0] = $1.value ? atof($1.value) : 0.0;
                break;
            case TYPE_CHAR:
                $$.elements = malloc(sizeof(char));
                ((char *)$$.elements)[0] = $1.value ? $1.value[1] : '\0';
                break;
            case TYPE_STRING:
                $$.elements = malloc(sizeof(char *));
                ((char **)$$.elements)[0] = $1.value ? strdup($1.value) : strdup("");
                break;
            case TYPE_BOOLEAN:
                $$.elements = malloc(sizeof(int));
                ((int *)$$.elements)[0] = $1.value ? (strcmp($1.value, "true") == 0) : 0;
                break;
            default:
                yyerror("Unsupported array element type");
        }
    }
    | array_elements COMMA expression
    {
        if ($1.element_type != $3.type) yyerror("Array elements must be of the same type");
        $$.size = $1.size + 1;
        $$.element_type = $1.element_type;
        $$.row_sizes = NULL;
        switch ($1.element_type) {
            case TYPE_INT:
                $$.elements = realloc($1.elements, $$.size * sizeof(int));
                ((int *)$$.elements)[$$.size - 1] = $3.value ? atoi($3.value) : 0;
                break;
            case TYPE_FLOAT:
                $$.elements = realloc($1.elements, $$.size * sizeof(float));
                ((float *)$$.elements)[$$.size - 1] = $3.value ? atof($3.value) : 0.0;
                break;
            case TYPE_DOUBLE:
                $$.elements = realloc($1.elements, $$.size * sizeof(double));
                ((double *)$$.elements)[$$.size - 1] = $3.value ? atof($3.value) : 0.0;
                break;
            case TYPE_CHAR:
                $$.elements = realloc($1.elements, $$.size * sizeof(char));
                ((char *)$$.elements)[$$.size - 1] = $3.value ? $3.value[1] : '\0';
                break;
            case TYPE_STRING:
                $$.elements = realloc($1.elements, $$.size * sizeof(char *));
                ((char **)$$.elements)[$$.size - 1] = $3.value ? strdup($3.value) : strdup("");
                break;
            case TYPE_BOOLEAN:
                $$.elements = realloc($1.elements, $$.size * sizeof(int));
                ((int *)$$.elements)[$$.size - 1] = $3.value ? (strcmp($3.value, "true") == 0) : 0;
                break;
            default:
                yyerror("Unsupported array element type");
        }
    }
    ;

array_2d_elements: array_initializer
    {
        if ($1.row_sizes) yyerror("Nested arrays beyond 2D not supported");
        $$.size = 1;
        $$.element_type = $1.element_type;
        $$.row_sizes = malloc(sizeof(int));
        $$.row_sizes[0] = $1.size;
        switch ($1.element_type) {
            case TYPE_INT:
                $$.elements = malloc(sizeof(int *));
                ((int **)$$.elements)[0] = $1.elements;
                break;
            case TYPE_FLOAT:
                $$.elements = malloc(sizeof(float *));
                ((float **)$$.elements)[0] = $1.elements;
                break;
            case TYPE_DOUBLE:
                $$.elements = malloc(sizeof(double *));
                ((double **)$$.elements)[0] = $1.elements;
                break;
            case TYPE_CHAR:
                $$.elements = malloc(sizeof(char *));
                ((char **)$$.elements)[0] = $1.elements;
                break;
            case TYPE_STRING:
                $$.elements = malloc(sizeof(char **));
                ((char ***) $$.elements)[0] = $1.elements;
                break;
            case TYPE_BOOLEAN:
                $$.elements = malloc(sizeof(int *));
                ((int **)$$.elements)[0] = $1.elements;
                break;
            default:
                yyerror("Unsupported 2D array element type");
        }
    }
    | array_2d_elements COMMA array_initializer
    {
        if ($1.element_type != $3.element_type) yyerror("2D array rows must be of the same type");
        if ($3.row_sizes) yyerror("Nested arrays beyond 2D not supported");
        $$.size = $1.size + 1;
        $$.element_type = $1.element_type;
        $$.row_sizes = realloc($1.row_sizes, $$.size * sizeof(int));
        $$.row_sizes[$$.size - 1] = $3.size;
        switch ($1.element_type) {
            case TYPE_INT:
                $$.elements = realloc($1.elements, $$.size * sizeof(int *));
                ((int **)$$.elements)[$$.size - 1] = $3.elements;
                break;
            case TYPE_FLOAT:
                $$.elements = realloc($1.elements, $$.size * sizeof(float *));
                ((float **)$$.elements)[$$.size - 1] = $3.elements;
                break;
            case TYPE_DOUBLE:
                $$.elements = realloc($1.elements, $$.size * sizeof(double *));
                ((double **)$$.elements)[$$.size - 1] = $3.elements;
                break;
            case TYPE_CHAR:
                $$.elements = realloc($1.elements, $$.size * sizeof(char *));
                ((char **)$$.elements)[$$.size - 1] = $3.elements;
                break;
            case TYPE_STRING:
                $$.elements = realloc($1.elements, $$.size * sizeof(char **));
                ((char ***) $$.elements)[$$.size - 1] = $3.elements;
                break;
            case TYPE_BOOLEAN:
                $$.elements = realloc($1.elements, $$.size * sizeof(int *));
                ((int **)$$.elements)[$$.size - 1] = $3.elements;
                break;
            default:
                yyerror("Unsupported 2D array element type");
        }
    }
    ;

%%

int main() {
    sym_table = create_symbol_table(101);
    if (!sym_table || !sym_table->buckets) {
    printf("Failed to create symbol table\n");
    exit(1);
}

    meta_table = create_symbol_table(101);
    quad_list = create_quad_list();
    int result = yyparse();
    free_symbol_table(sym_table);
    free_symbol_table(meta_table);
    free_quad_list(quad_list);
    return result;
}
