#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "symbol_table.h"

#define HASH_MULTIPLIER 31
#define INITIAL_QUAD_CAPACITY 100

static unsigned int hash(const char *str, int size) {
    unsigned int h = 0;
    while (*str) {
        h = h * HASH_MULTIPLIER + (unsigned char)(*str++);
    }
    return h % size;
}

SymbolTable *create_symbol_table(int size) {
    SymbolTable *table = malloc(sizeof(SymbolTable));
    table->size = size;
    table->buckets = calloc(size, sizeof(HashNode *));
    return table;
}

void free_symbol_table(SymbolTable *table) {
    for (int i = 0; i < table->size; i++) {
        HashNode *node = table->buckets[i];
        while (node) {
            HashNode *next = node->next;
            free(node->symbol->name);
            if (node->symbol->is_initialized) {
                if (node->symbol->type == TYPE_STRING || node->symbol->type == TYPE_IMPORT || node->symbol->type == TYPE_CLASS) {
                    free(node->symbol->value.s_val);
                } else if (node->symbol->type >= TYPE_INT_ARRAY && node->symbol->type <= TYPE_BOOLEAN_ARRAY) {
                    if (node->symbol->type == TYPE_STRING_ARRAY) {
                        char **elements = (char **)node->symbol->value.array.elements;
                        for (int j = 0; j < node->symbol->value.array.size; j++) {
                            free(elements[j]);
                        }
                    }
                    free(node->symbol->value.array.elements);
                } else if (node->symbol->type >= TYPE_INT_ARRAY_2D && node->symbol->type <= TYPE_BOOLEAN_ARRAY_2D) {
                    if (node->symbol->type == TYPE_STRING_ARRAY_2D) {
                        char ***elements = (char ***)node->symbol->value.array.elements;
                        for (int j = 0; j < node->symbol->value.array.size; j++) {
                            for (int k = 0; k < node->symbol->value.array.row_sizes[j]; k++) {
                                free(elements[j][k]);
                            }
                            free(elements[j]);
                        }
                    } else {
                        void **elements = (void **)node->symbol->value.array.elements;
                        for (int j = 0; j < node->symbol->value.array.size; j++) {
                            free(elements[j]);
                        }
                    }
                    free(node->symbol->value.array.elements);
                    free(node->symbol->value.array.row_sizes);
                } else if (node->symbol->type == TYPE_METHOD) {
                    free(node->symbol->value.method.params.types);
                }
            }
            free(node->symbol);
            free(node);
            node = next;
        }
    }
    free(table->buckets);
    free(table);
}

int insert_symbol(SymbolTable *table, char *name, DataType type, int is_final) {
    unsigned int index = hash(name, table->size);
    HashNode *node = table->buckets[index];
    while (node) {
        if (strcmp(node->symbol->name, name) == 0) {
            return 0; /* Duplicate symbol */
        }
        node = node->next;
    }

    Symbol *symbol = malloc(sizeof(Symbol));
    if (!symbol) {
        printf("Memory allocation failed for symbol: %s\n", name);
        exit(1);
    }
    symbol->name = strdup(name);
    symbol->type = type;
    symbol->is_final = is_final;
    symbol->is_initialized = 0;
    symbol->dimensions.rows = 0;
    symbol->dimensions.cols = 0;
    if (type >= TYPE_INT_ARRAY && type <= TYPE_BOOLEAN_ARRAY_2D) {
        symbol->value.array.elements = NULL;
        symbol->value.array.size = 0;
        symbol->value.array.row_sizes = NULL;
    } else if (type == TYPE_METHOD) {
        symbol->value.method.params.types = NULL;
        symbol->value.method.params.count = 0;
    }

    HashNode *new_node = malloc(sizeof(HashNode));
    new_node->symbol = symbol;
    new_node->next = table->buckets[index];
    table->buckets[index] = new_node;
    return 1;
}

int insert_multiple_symbols(SymbolTable *table, char **names, int count, DataType type, int is_final) {
    for (int i = 0; i < count; i++) {
        if (!insert_symbol(table, names[i], type, is_final)) {
            return 0; /* Duplicate symbol */
        }
    }
    return 1;
}

int insert_method(SymbolTable *table, char *name, DataType return_type, DataType *param_types, int param_count) {
    if (!insert_symbol(table, name, TYPE_METHOD, 0)) {
        return 0;
    }
    Symbol *sym = lookup_symbol(table, name);
    sym->is_initialized = 1;
    sym->value.method.name = strdup(name);
    sym->value.method.return_type = return_type;
    sym->value.method.params.count = param_count;
    sym->value.method.params.types = malloc(param_count * sizeof(DataType));
    memcpy(sym->value.method.params.types, param_types, param_count * sizeof(DataType));
    return 1;
}

int update_symbol_value(SymbolTable *table, char *name, DataType type, char *value) {
    Symbol *sym = lookup_symbol(table, name);
    if (!sym) return 0;
    if (sym->is_final && sym->is_initialized) return 0;
    if (sym->type >= TYPE_INT_ARRAY && sym->type <= TYPE_BOOLEAN_ARRAY_2D) return 0;
    if (!value) {
        printf("Warning: NULL value for symbol %s\n", name);
        return 0;
    }
    sym->is_initialized = 1;
    switch (type) {
        case TYPE_INT:
            sym->value.i_val = atoi(value);
            break;
        case TYPE_FLOAT:
            sym->value.f_val = atof(value);
            break;
        case TYPE_DOUBLE:
            sym->value.d_val = atof(value);
            break;
        case TYPE_CHAR:
            sym->value.c_val = value[1];
            break;
        case TYPE_STRING:
        case TYPE_IMPORT:
        case TYPE_CLASS:
            if (sym->is_initialized) free(sym->value.s_val);
            sym->value.s_val = strdup(value);
            printf("Updated %s to class instance %s\n", name, sym->value.s_val);
        break;
        case TYPE_BOOLEAN:
            sym->value.b_val = strcmp(value, "true") == 0 ? 1 : 0;
            break;
    }
    return 1;
}

int update_array_value(SymbolTable *table, char *name, DataType type, void *elements, int size, int *row_sizes) {
    Symbol *sym = lookup_symbol(table, name);
    if (!sym) return 0;
    if (sym->is_final && sym->is_initialized) return 0;
    if (sym->type != type) return 0;
    if (sym->dimensions.rows > 0) {
        if (sym->type >= TYPE_INT_ARRAY && sym->type <= TYPE_BOOLEAN_ARRAY) {
            if (sym->dimensions.rows != size) return 0; /* Static 1D array size mismatch */
        } else if (sym->type >= TYPE_INT_ARRAY_2D && sym->type <= TYPE_BOOLEAN_ARRAY_2D) {
            if (sym->dimensions.rows != size || (row_sizes && sym->dimensions.cols != row_sizes[0])) {
                return 0; /* Static 2D array size mismatch */
            }
        }
    }

    sym->is_initialized = 1;
    if (sym->value.array.elements) {
        if (sym->type >= TYPE_INT_ARRAY && sym->type <= TYPE_BOOLEAN_ARRAY) {
            if (sym->type == TYPE_STRING_ARRAY) {
                char **old_elements = (char **)sym->value.array.elements;
                for (int i = 0; i < sym->value.array.size; i++) free(old_elements[i]);
            }
            free(sym->value.array.elements);
        } else if (sym->type >= TYPE_INT_ARRAY_2D && sym->type <= TYPE_BOOLEAN_ARRAY_2D) {
            if (sym->type == TYPE_STRING_ARRAY_2D) {
                char ***old_elements = (char ***)sym->value.array.elements;
                for (int i = 0; i < sym->value.array.size; i++) {
                    for (int j = 0; j < sym->value.array.row_sizes[i]; j++) free(old_elements[i][j]);
                    free(old_elements[i]);
                }
            } else {
                void **old_elements = (void **)sym->value.array.elements;
                for (int j = 0; j < sym->value.array.size; j++) {
                    free(old_elements[j]);
                }
            }
            free(sym->value.array.elements);
            free(sym->value.array.row_sizes);
        }
    }

    sym->value.array.size = size;
    if (type >= TYPE_INT_ARRAY_2D && type <= TYPE_BOOLEAN_ARRAY_2D) {
        sym->value.array.row_sizes = malloc(size * sizeof(int));
        memcpy(sym->value.array.row_sizes, row_sizes, size * sizeof(int));
    }

    switch (type) {
        case TYPE_INT_ARRAY:
            sym->value.array.elements = malloc(size * sizeof(int));
            memcpy(sym->value.array.elements, elements, size * sizeof(int));
            break;
        case TYPE_FLOAT_ARRAY:
            sym->value.array.elements = malloc(size * sizeof(float));
            memcpy(sym->value.array.elements, elements, size * sizeof(float));
            break;
        case TYPE_DOUBLE_ARRAY:
            sym->value.array.elements = malloc(size * sizeof(double));
            memcpy(sym->value.array.elements, elements, size * sizeof(double));
            break;
        case TYPE_CHAR_ARRAY:
            sym->value.array.elements = malloc(size * sizeof(char));
            memcpy(sym->value.array.elements, elements, size * sizeof(char));
            break;
        case TYPE_STRING_ARRAY:
            sym->value.array.elements = malloc(size * sizeof(char *));
            for (int i = 0; i < size; i++) {
                ((char **)sym->value.array.elements)[i] = strdup(((char **)elements)[i]);
            }
            break;
        case TYPE_BOOLEAN_ARRAY:
            sym->value.array.elements = malloc(size * sizeof(int));
            memcpy(sym->value.array.elements, elements, size * sizeof(int));
            break;
        case TYPE_INT_ARRAY_2D:
            sym->value.array.elements = malloc(size * sizeof(int *));
            for (int i = 0; i < size; i++) {
                ((int **)sym->value.array.elements)[i] = malloc(row_sizes[i] * sizeof(int));
                memcpy(((int **)sym->value.array.elements)[i], ((int **)elements)[i], row_sizes[i] * sizeof(int));
            }
            break;
        case TYPE_FLOAT_ARRAY_2D:
            sym->value.array.elements = malloc(size * sizeof(float *));
            for (int i = 0; i < size; i++) {
                ((float **)sym->value.array.elements)[i] = malloc(row_sizes[i] * sizeof(float));
                memcpy(((float **)sym->value.array.elements)[i], ((float **)elements)[i], row_sizes[i] * sizeof(float));
            }
            break;
        case TYPE_DOUBLE_ARRAY_2D:
            sym->value.array.elements = malloc(size * sizeof(double *));
            for (int i = 0; i < size; i++) {
                ((double **)sym->value.array.elements)[i] = malloc(row_sizes[i] * sizeof(double));
                memcpy(((double **)sym->value.array.elements)[i], ((double **)elements)[i], row_sizes[i] * sizeof(double));
            }
            break;
        case TYPE_CHAR_ARRAY_2D:
            sym->value.array.elements = malloc(size * sizeof(char *));
            for (int i = 0; i < size; i++) {
                ((char **)sym->value.array.elements)[i] = malloc(row_sizes[i] * sizeof(char));
                memcpy(((char **)sym->value.array.elements)[i], ((char **)elements)[i], row_sizes[i] * sizeof(char));
            }
            break;
        case TYPE_STRING_ARRAY_2D:
            sym->value.array.elements = malloc(size * sizeof(char **));
            for (int i = 0; i < size; i++) {
                ((char ***)sym->value.array.elements)[i] = malloc(row_sizes[i] * sizeof(char *));
                for (int j = 0; j < row_sizes[i]; j++) {
                    ((char ***)sym->value.array.elements)[i][j] = strdup(((char ***)elements)[i][j]);
                }
            }
            break;
        case TYPE_BOOLEAN_ARRAY_2D:
            sym->value.array.elements = malloc(size * sizeof(int *));
            for (int i = 0; i < size; i++) {
                ((int **)sym->value.array.elements)[i] = malloc(row_sizes[i] * sizeof(int));
                memcpy(((int **)sym->value.array.elements)[i], ((int **)elements)[i], row_sizes[i] * sizeof(int));
            }
            break;
        default:
            return 0;
    }
    return 1;
}

int update_static_array(SymbolTable *table, char *name, DataType type, void *elements, int rows, int cols) {
    Symbol *sym = lookup_symbol(table, name);
    if (!sym) return 0;
    if (sym->is_final && sym->is_initialized) return 0;
    if (sym->type != type) return 0;
    if (sym->dimensions.rows != rows || sym->dimensions.cols != cols) return 0;

    sym->is_initialized = 1;
    if (sym->value.array.elements) {
        if (sym->type >= TYPE_INT_ARRAY_2D && sym->type <= TYPE_BOOLEAN_ARRAY_2D) {
            if (sym->type == TYPE_STRING_ARRAY_2D) {
                char ***old_elements = (char ***)sym->value.array.elements;
                for (int i = 0; i < sym->value.array.size; i++) {
                    for (int j = 0; j < sym->value.array.row_sizes[i]; j++) free(old_elements[i][j]);
                    free(old_elements[i]);
                }
            } else {
                void **old_elements = (void **)sym->value.array.elements;
                for (int j = 0; j < sym->value.array.size; j++) {
                    free(old_elements[j]);
                }
            }
            free(sym->value.array.elements);
            free(sym->value.array.row_sizes);
        }
    }

    sym->value.array.size = rows;
    sym->value.array.row_sizes = malloc(rows * sizeof(int));
    for (int i = 0; i < rows; i++) sym->value.array.row_sizes[i] = cols;

    switch (type) {
        case TYPE_INT_ARRAY_2D:
            sym->value.array.elements = malloc(rows * sizeof(int *));
            for (int i = 0; i < rows; i++) {
                ((int **)sym->value.array.elements)[i] = elements ? malloc(cols * sizeof(int)) : calloc(cols, sizeof(int));
                if (elements) memcpy(((int **)sym->value.array.elements)[i], ((int **)elements)[i], cols * sizeof(int));
            }
            break;
        case TYPE_FLOAT_ARRAY_2D:
            sym->value.array.elements = malloc(rows * sizeof(float *));
            for (int i = 0; i < rows; i++) {
                ((float **)sym->value.array.elements)[i] = elements ? malloc(cols * sizeof(float)) : calloc(cols, sizeof(float));
                if (elements) memcpy(((float **)sym->value.array.elements)[i], ((float **)elements)[i], cols * sizeof(float));
            }
            break;
        case TYPE_DOUBLE_ARRAY_2D:
            sym->value.array.elements = malloc(rows * sizeof(double *));
            for (int i = 0; i < rows; i++) {
                ((double **)sym->value.array.elements)[i] = elements ? malloc(cols * sizeof(double)) : calloc(cols, sizeof(double));
                if (elements) memcpy(((double **)sym->value.array.elements)[i], ((double **)elements)[i], cols * sizeof(double));
            }
            break;
        case TYPE_CHAR_ARRAY_2D:
            sym->value.array.elements = malloc(rows * sizeof(char *));
            for (int i = 0; i < rows; i++) {
                ((char **)sym->value.array.elements)[i] = elements ? malloc(cols * sizeof(char)) : calloc(cols, sizeof(char));
                if (elements) memcpy(((char **)sym->value.array.elements)[i], ((char **)elements)[i], cols * sizeof(char));
            }
            break;
        case TYPE_STRING_ARRAY_2D:
            sym->value.array.elements = malloc(rows * sizeof(char **));
            for (int i = 0; i < rows; i++) {
                ((char ***)sym->value.array.elements)[i] = malloc(cols * sizeof(char *));
                for (int j = 0; j < cols; j++) {
                    ((char ***)sym->value.array.elements)[i][j] = elements ? strdup(((char ***)elements)[i][j]) : strdup("");
                }
            }
            break;
        case TYPE_BOOLEAN_ARRAY_2D:
            sym->value.array.elements = malloc(rows * sizeof(int *));
            for (int i = 0; i < rows; i++) {
                ((int **)sym->value.array.elements)[i] = elements ? malloc(cols * sizeof(int)) : calloc(cols, sizeof(int));
                if (elements) memcpy(((int **)sym->value.array.elements)[i], ((int **)elements)[i], cols * sizeof(int));
            }
            break;
        default:
            return 0;
    }
    return 1;
}

int update_static_array_1d(SymbolTable *table, char *name, DataType type, void *elements, int size) {
    Symbol *sym = lookup_symbol(table, name);
    if (!sym) return 0;
    if (sym->is_final && sym->is_initialized) return 0;
    if (sym->type != type) return 0;
    if (sym->dimensions.rows != size) return 0;

    sym->is_initialized = 1;
    if (sym->value.array.elements) {
        if (sym->type == TYPE_STRING_ARRAY) {
            char **old_elements = (char **)sym->value.array.elements;
            for (int i = 0; i < sym->value.array.size; i++) free(old_elements[i]);
        }
        free(sym->value.array.elements);
    }

    sym->value.array.size = size;
    sym->value.array.row_sizes = NULL;

    switch (type) {
        case TYPE_INT_ARRAY:
            sym->value.array.elements = elements ? malloc(size * sizeof(int)) : calloc(size, sizeof(int));
            if (elements) memcpy(sym->value.array.elements, elements, size * sizeof(int));
            break;
        case TYPE_FLOAT_ARRAY:
            sym->value.array.elements = elements ? malloc(size * sizeof(float)) : calloc(size, sizeof(float));
            if (elements) memcpy(sym->value.array.elements, elements, size * sizeof(float));
            break;
        case TYPE_DOUBLE_ARRAY:
            sym->value.array.elements = elements ? malloc(size * sizeof(double)) : calloc(size, sizeof(double));
            if (elements) memcpy(sym->value.array.elements, elements, size * sizeof(double));
            break;
        case TYPE_CHAR_ARRAY:
            sym->value.array.elements = elements ? malloc(size * sizeof(char)) : calloc(size, sizeof(char));
            if (elements) memcpy(sym->value.array.elements, elements, size * sizeof(char));
            break;
        case TYPE_STRING_ARRAY:
            sym->value.array.elements = malloc(size * sizeof(char *));
            for (int i = 0; i < size; i++) {
                ((char **)sym->value.array.elements)[i] = elements ? strdup(((char **)elements)[i]) : strdup("");
            }
            break;
        case TYPE_BOOLEAN_ARRAY:
            sym->value.array.elements = elements ? malloc(size * sizeof(int)) : calloc(size, sizeof(int));
            if (elements) memcpy(sym->value.array.elements, elements, size * sizeof(int));
            break;
        default:
            return 0;
    }
    return 1;
}

Symbol *lookup_symbol(SymbolTable *table, char *name) {
    unsigned int index = hash(name, table->size);
    HashNode *node = table->buckets[index];
    while (node) {
        if (strcmp(node->symbol->name, name) == 0) {
            return node->symbol;
        }
        node = node->next;
    }
    return NULL;
}

int get_array_element(SymbolTable *table, char *name, int index1, int index2, DataType *type, char **value) {
    Symbol *sym = lookup_symbol(table, name);
    if (!sym) return 0;
    if (sym->type < TYPE_INT_ARRAY || sym->type > TYPE_BOOLEAN_ARRAY_2D) return 0;
    if (!sym->is_initialized) return 0;

    char result[32];
    if (sym->type >= TYPE_INT_ARRAY && sym->type <= TYPE_BOOLEAN_ARRAY) {
        if (index1 < 0 || index1 >= sym->value.array.size || index2 != -1) {
            if (sym->dimensions.rows > 0 && index1 >= sym->dimensions.rows) return 0;
            return 0;
        }
        switch (sym->type) {
            case TYPE_INT_ARRAY:
                *type = TYPE_INT;
                sprintf(result, "%d", ((int *)sym->value.array.elements)[index1]);
                break;
            case TYPE_FLOAT_ARRAY:
                *type = TYPE_FLOAT;
                sprintf(result, "%f", ((float *)sym->value.array.elements)[index1]);
                break;
            case TYPE_DOUBLE_ARRAY:
                *type = TYPE_DOUBLE;
                sprintf(result, "%f", ((double *)sym->value.array.elements)[index1]);
                break;
            case TYPE_CHAR_ARRAY:
                *type = TYPE_CHAR;
                sprintf(result, "'%c'", ((char *)sym->value.array.elements)[index1]);
                break;
            case TYPE_STRING_ARRAY:
                *type = TYPE_STRING;
                *value = strdup(((char **)sym->value.array.elements)[index1]);
                return 1;
            case TYPE_BOOLEAN_ARRAY:
                *type = TYPE_BOOLEAN;
                sprintf(result, "%s", ((int *)sym->value.array.elements)[index1] ? "true" : "false");
                break;
            default:
                return 0;
        }
    } else {
        if (index1 < 0 || index1 >= sym->value.array.size || index2 < 0 || index2 >= sym->value.array.row_sizes[index1]) {
            if (sym->dimensions.rows > 0 && (index1 >= sym->dimensions.rows || index2 >= sym->dimensions.cols)) return 0;
            return 0;
        }
        switch (sym->type) {
            case TYPE_INT_ARRAY_2D:
                *type = TYPE_INT;
                sprintf(result, "%d", ((int **)sym->value.array.elements)[index1][index2]);
                break;
            case TYPE_FLOAT_ARRAY_2D:
                *type = TYPE_FLOAT;
                sprintf(result, "%f", ((float **)sym->value.array.elements)[index1][index2]);
                break;
            case TYPE_DOUBLE_ARRAY_2D:
                *type = TYPE_DOUBLE;
                sprintf(result, "%f", ((double **)sym->value.array.elements)[index1][index2]);
                break;
            case TYPE_CHAR_ARRAY_2D:
                *type = TYPE_CHAR;
                sprintf(result, "'%c'", ((char **)sym->value.array.elements)[index1][index2]);
                break;
            case TYPE_STRING_ARRAY_2D:
                *type = TYPE_STRING;
                *value = strdup(((char ***)sym->value.array.elements)[index1][index2]);
                return 1;
            case TYPE_BOOLEAN_ARRAY_2D:
                *type = TYPE_BOOLEAN;
                sprintf(result, "%s", ((int **)sym->value.array.elements)[index1][index2] ? "true" : "false");
                break;
            default:
                return 0;
        }
    }
    *value = strdup(result);
    return 1;
}


QuadList *create_quad_list() {
    QuadList *list = malloc(sizeof(QuadList));
    list->size = 0;
    list->capacity = INITIAL_QUAD_CAPACITY;
    list->quads = malloc(list->capacity * sizeof(Quadruplet));
    if (!list->quads) {
        printf("Failed to allocate quad list\n");
        exit(1);
    }
    return list;
}

void add_quad(QuadList *list, char *op, char *arg1, char *arg2, char *result) {
    if (list->size >= list->capacity) {
        list->capacity *= 2;
        list->quads = realloc(list->quads, list->capacity * sizeof(Quadruplet));
    }
    Quadruplet *quad = &list->quads[list->size++];
    quad->op = op ? strdup(op) : NULL;
    quad->arg1 = arg1 ? strdup(arg1) : NULL;
    quad->arg2 = arg2 ? strdup(arg2) : NULL;
    quad->result = result ? strdup(result) : NULL;
}

void print_quads(QuadList *list) {
    printf("\nQuadruplets:\n");
    printf("----------------------------------------\n");
    for (int i = 0; i < list->size; i++) {
        Quadruplet *quad = &list->quads[i];
        printf("%d: (%s, %s, %s, %s)\n", i, quad->op ? quad->op : "",
               quad->arg1 ? quad->arg1 : "", quad->arg2 ? quad->arg2 : "",
               quad->result ? quad->result : "");
    }
    printf("----------------------------------------\n");
}

void free_quad_list(QuadList *list) {
    for (int i = 0; i < list->size; i++) {
        Quadruplet *quad = &list->quads[i];
        free(quad->op);
        free(quad->arg1);
        free(quad->arg2);
        free(quad->result);
    }
    free(list->quads);
    free(list);
}

void print_symbol_table(SymbolTable *table) {
    printf("\nSymbol Table Contents:\n");
    printf("----------------------------------------\n");
    printf("Name\tType\t\tFinal\tInitialized\tValue\n");
    printf("----------------------------------------\n");

    for (int i = 0; i < table->size; i++) {
        HashNode *node = table->buckets[i];
        while (node) {
            Symbol *sym = node->symbol;
            const char *type_str;
            switch (sym->type) {
                case TYPE_INT: type_str = "int"; break;
                case TYPE_FLOAT: type_str = "float"; break;
                case TYPE_DOUBLE: type_str = "double"; break;
                case TYPE_CHAR: type_str = "char"; break;
                case TYPE_STRING: type_str = "String"; break;
                case TYPE_BOOLEAN: type_str = "boolean"; break;
                case TYPE_INT_ARRAY: type_str = sym->dimensions.rows > 0 ? "int[] (static)" : "int[]"; break;
                case TYPE_FLOAT_ARRAY: type_str = sym->dimensions.rows > 0 ? "float[] (static)" : "float[]"; break;
                case TYPE_DOUBLE_ARRAY: type_str = sym->dimensions.rows > 0 ? "double[] (static)" : "double[]"; break;
                case TYPE_CHAR_ARRAY: type_str = sym->dimensions.rows > 0 ? "char[] (static)" : "char[]"; break;
                case TYPE_STRING_ARRAY: type_str = sym->dimensions.rows > 0 ? "String[] (static)" : "String[]"; break;
                case TYPE_BOOLEAN_ARRAY: type_str = sym->dimensions.rows > 0 ? "boolean[] (static)" : "boolean[]"; break;
                case TYPE_INT_ARRAY_2D: type_str = sym->dimensions.rows > 0 ? "int[][] (static)" : "int[][]"; break;
                case TYPE_FLOAT_ARRAY_2D: type_str = sym->dimensions.rows > 0 ? "float[][] (static)" : "float[][]"; break;
                case TYPE_DOUBLE_ARRAY_2D: type_str = sym->dimensions.rows > 0 ? "double[][] (static)" : "double[][]"; break;
                case TYPE_CHAR_ARRAY_2D: type_str = sym->dimensions.rows > 0 ? "char[][] (static)" : "char[][]"; break;
                case TYPE_STRING_ARRAY_2D: type_str = sym->dimensions.rows > 0 ? "String[][] (static)" : "String[][]"; break;
                case TYPE_BOOLEAN_ARRAY_2D: type_str = sym->dimensions.rows > 0 ? "boolean[][] (static)" : "boolean[][]"; break;
                case TYPE_IMPORT: type_str = "import"; break;
                case TYPE_CLASS: type_str = "class"; break;
                case TYPE_METHOD: type_str = "method"; break;
                case TYPE_VOID: type_str = "void"; break;
                default: type_str = "unknown"; break;
            }

            printf("%s\t%-10s\t%d\t%d\t\t", sym->name, type_str, sym->is_final, sym->is_initialized);
            if (sym->dimensions.rows > 0) {
                if (sym->type >= TYPE_INT_ARRAY && sym->type <= TYPE_BOOLEAN_ARRAY) {
                    printf("[%d] ", sym->dimensions.rows);
                } else {
                    printf("[%d][%d] ", sym->dimensions.rows, sym->dimensions.cols);
                }
            }

            if (sym->is_initialized) {
                switch (sym->type) {
                    case TYPE_INT:
                        printf("%d", sym->value.i_val); break;
                    case TYPE_FLOAT:
                        printf("%f", sym->value.f_val); break;
                    case TYPE_DOUBLE:
                        printf("%f", sym->value.d_val); break;
                    case TYPE_CHAR:
                        printf("'%c'", sym->value.c_val); break;
                    case TYPE_STRING:
                    case TYPE_IMPORT:
                    case TYPE_CLASS:
                        printf("\"%s\"", sym->value.s_val); break;
                    case TYPE_BOOLEAN:
                        printf("%s", sym->value.b_val ? "true" : "false"); break;
                    case TYPE_INT_ARRAY:
                        printf("{");
                        for (int j = 0; j < sym->value.array.size; j++) {
                            printf("%d", ((int *)sym->value.array.elements)[j]);
                            if (j < sym->value.array.size - 1) printf(", ");
                        }
                        printf("}");
                        break;
                    case TYPE_FLOAT_ARRAY:
                        printf("{");
                        for (int j = 0; j < sym->value.array.size; j++) {
                            printf("%f", ((float *)sym->value.array.elements)[j]);
                            if (j < sym->value.array.size - 1) printf(", ");
                        }
                        printf("}");
                        break;
                    case TYPE_DOUBLE_ARRAY:
                        printf("{");
                        for (int j = 0; j < sym->value.array.size; j++) {
                            printf("%f", ((double *)sym->value.array.elements)[j]);
                            if (j < sym->value.array.size - 1) printf(", ");
                        }
                        printf("}");
                        break;
                    case TYPE_CHAR_ARRAY:
                        printf("{");
                        for (int j = 0; j < sym->value.array.size; j++) {
                            printf("'%c'", ((char *)sym->value.array.elements)[j]);
                            if (j < sym->value.array.size - 1) printf(", ");
                        }
                        printf("}");
                        break;
                    case TYPE_STRING_ARRAY:
                        printf("{");
                        for (int j = 0; j < sym->value.array.size; j++) {
                            printf("\"%s\"", ((char **)sym->value.array.elements)[j]);
                            if (j < sym->value.array.size - 1) printf(", ");
                        }
                        printf("}");
                        break;
                    case TYPE_BOOLEAN_ARRAY:
                        printf("{");
                        for (int j = 0; j < sym->value.array.size; j++) {
                            printf("%s", ((int *)sym->value.array.elements)[j] ? "true" : "false");
                            if (j < sym->value.array.size - 1) printf(", ");
                        }
                        printf("}");
                        break;
                    case TYPE_INT_ARRAY_2D:
                        printf("{");
                        for (int j = 0; j < sym->value.array.size; j++) {
                            printf("{");
                            for (int k = 0; k < sym->value.array.row_sizes[j]; k++) {
                                printf("%d", ((int **)sym->value.array.elements)[j][k]);
                                if (k < sym->value.array.row_sizes[j] - 1) printf(", ");
                            }
                            printf("}");
                            if (j < sym->value.array.size - 1) printf(", ");
                        }
                        printf("}");
                        break;
                    case TYPE_FLOAT_ARRAY_2D:
                        printf("{");
                        for (int j = 0; j < sym->value.array.size; j++) {
                            printf("{");
                            for (int k = 0; k < sym->value.array.row_sizes[j]; k++) {
                                printf("%f", ((float **)sym->value.array.elements)[j][k]);
                                if (k < sym->value.array.row_sizes[j] - 1) printf(", ");
                            }
                            printf("}");
                            if (j < sym->value.array.size - 1) printf(", ");
                        }
                        printf("}");
                        break;
                    case TYPE_DOUBLE_ARRAY_2D:
                        printf("{");
                        for (int j = 0; j < sym->value.array.size; j++) {
                            printf("{");
                            for (int k = 0; k < sym->value.array.row_sizes[j]; k++) {
                                printf("%f", ((double **)sym->value.array.elements)[j][k]);
                                if (k < sym->value.array.row_sizes[j] - 1) printf(", ");
                            }
                            printf("}");
                            if (j < sym->value.array.size - 1) printf(", ");
                        }
                        printf("}");
                        break;
                    case TYPE_CHAR_ARRAY_2D:
                        printf("{");
                        for (int j = 0; j < sym->value.array.size; j++) {
                            printf("{");
                            for (int k = 0; k < sym->value.array.row_sizes[j]; k++) {
                                printf("'%c'", ((char **)sym->value.array.elements)[j][k]);
                                if (k < sym->value.array.row_sizes[j] - 1) printf(", ");
                            }
                            printf("}");
                            if (j < sym->value.array.size - 1) printf(", ");
                        }
                        printf("}");
                        break;
                    case TYPE_STRING_ARRAY_2D:
                        printf("{");
                        for (int j = 0; j < sym->value.array.size; j++) {
                            printf("{");
                            for (int k = 0; k < sym->value.array.row_sizes[j]; k++) {
                                printf("\"%s\"", ((char ***)sym->value.array.elements)[j][k]);
                                if (k < sym->value.array.row_sizes[j] - 1) printf(", ");
                            }
                            printf("}");
                            if (j < sym->value.array.size - 1) printf(", ");
                        }
                        printf("}");
                        break;
                    case TYPE_BOOLEAN_ARRAY_2D:
                        printf("{");
                        for (int j = 0; j < sym->value.array.size; j++) {
                            printf("{");
                            for (int k = 0; k < sym->value.array.row_sizes[j]; k++) {
                                printf("%s", ((int **)sym->value.array.elements)[j][k] ? "true" : "false");
                                if (k < sym->value.array.row_sizes[j] - 1) printf(", ");
                            }
                            printf("}");
                            if (j < sym->value.array.size - 1) printf(", ");
                        }
                        printf("}");
                        break;
                    case TYPE_METHOD:
                        printf("%s(", sym->value.method.name);
                        for (int j = 0; j < sym->value.method.params.count; j++) {
                            switch (sym->value.method.params.types[j]) {
                                case TYPE_INT: printf("int"); break;
                                case TYPE_FLOAT: printf("float"); break;
                                case TYPE_DOUBLE: printf("double"); break;
                                case TYPE_CHAR: printf("char"); break;
                                case TYPE_STRING: printf("String"); break;
                                case TYPE_BOOLEAN: printf("boolean"); break;
                                default: printf("unknown"); break;
                            }
                            if (j < sym->value.method.params.count - 1) printf(", ");
                        }
                        printf(") -> ");
                        switch (sym->value.method.return_type) {
                            case TYPE_INT: printf("int"); break;
                            case TYPE_FLOAT: printf("float"); break;
                            case TYPE_DOUBLE: printf("double"); break;
                            case TYPE_CHAR: printf("char"); break;
                            case TYPE_STRING: printf("String"); break;
                            case TYPE_BOOLEAN: printf("boolean"); break;
                            case TYPE_VOID: printf("void"); break;
                            default: printf("unknown"); break;
                        }
                        break;
                }
            } else {
                printf("uninitialized");
            }
            printf("\n");
            node = node->next;
        }
    }
    printf("----------------------------------------\n");
}

