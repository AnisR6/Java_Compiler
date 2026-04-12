#ifndef SYMBOL_TABLE_H
#define SYMBOL_TABLE_H

typedef enum {
    TYPE_INT,
    TYPE_FLOAT,
    TYPE_DOUBLE,
    TYPE_CHAR,
    TYPE_STRING,
    TYPE_BOOLEAN,
    TYPE_INT_ARRAY,
    TYPE_FLOAT_ARRAY,
    TYPE_DOUBLE_ARRAY,
    TYPE_CHAR_ARRAY,
    TYPE_STRING_ARRAY,
    TYPE_BOOLEAN_ARRAY,
    TYPE_INT_ARRAY_2D,
    TYPE_FLOAT_ARRAY_2D,
    TYPE_DOUBLE_ARRAY_2D,
    TYPE_CHAR_ARRAY_2D,
    TYPE_STRING_ARRAY_2D,
    TYPE_BOOLEAN_ARRAY_2D,
    TYPE_IMPORT,
    TYPE_CLASS,
    TYPE_METHOD,
    TYPE_VOID
} DataType;

typedef struct {
    DataType *types;
    int count;
} ParamList;

typedef struct {
    char *name;
    DataType return_type;
    ParamList params;
} MethodSignature;

typedef struct {
    char *name;
    DataType type;
    int is_final;
    int is_initialized;
    struct {
        int rows;
        int cols;
    } dimensions;
    union {
        int i_val;
        float f_val;
        double d_val;
        char c_val;
        char *s_val;
        int b_val;
        struct {
            void *elements;
            int size;
            int *row_sizes;
        } array;
        MethodSignature method;
    } value;
} Symbol;

typedef struct {
    char *op;
    char *arg1;
    char *arg2;
    char *result;
} Quadruplet;

typedef struct {
    Quadruplet *quads;
    int size;
    int capacity;
} QuadList;

typedef struct HashNode {
    Symbol *symbol;
    struct HashNode *next;
} HashNode;

typedef struct {
    HashNode **buckets;
    int size;
} SymbolTable;

SymbolTable *create_symbol_table(int size);
void free_symbol_table(SymbolTable *table);
int insert_symbol(SymbolTable *table, char *name, DataType type, int is_final);
int insert_multiple_symbols(SymbolTable *table, char **names, int count, DataType type, int is_final);
int insert_method(SymbolTable *table, char *name, DataType return_type, DataType *param_types, int param_count);
int update_symbol_value(SymbolTable *table, char *name, DataType type, char *value);
int update_array_value(SymbolTable *table, char *name, DataType type, void *elements, int size, int *row_sizes);
int update_static_array(SymbolTable *table, char *name, DataType type, void *elements, int rows, int cols);
int update_static_array_1d(SymbolTable *table, char *name, DataType type, void *elements, int size);
Symbol *lookup_symbol(SymbolTable *table, char *name);
void print_symbol_table(SymbolTable *table);
int get_array_element(SymbolTable *table, char *name, int index1, int index2, DataType *type, char **value);

QuadList *create_quad_list();
void add_quad(QuadList *list, char *op, char *arg1, char *arg2, char *result);
void print_quads(QuadList *list);
void free_quad_list(QuadList *list);

#endif
