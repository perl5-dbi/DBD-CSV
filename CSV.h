#ifndef DBD_CSV_CSV_H
#define DBD_CSV_CSV_H 1


#include <DBIXS.h>


enum {
    DBD_CSV_COMMAND_SELECT,
    DBD_CSV_COMMAND_INSERT,
    DBD_CSV_COMMAND_UPDATE,
    DBD_CSV_COMMAND_DELETE
};


/*
 *  Various types used by the SQL parser
 */
typedef struct {
    char* ptr;
    int len;
} sql_string_t;

typedef struct {
    char* ptr;
    int len;
} sql_ident_t;

typedef struct {
    union {
        sql_string_t s;
        sql_ident_t  id;
        int          i;
        double       d;
    } data;
    int type;
} sql_val;

typedef struct {
    int command;
    int hasResult;
    int distinct;
} sql_stmt_t;

/*
 *  This is our part of the driver handle. We receive the handle as
 *  an "SV*", say "drh", and receive a pointer to the structure below
 *  by declaring
 *
 *    D_imp_drh(drh);
 *
 *  This declares a variable called "imp_drh" of type
 *  "struct imp_drh_st *".
 */
struct imp_drh_st {
    dbih_drc_t com;         /* MUST be first element in structure   */
};


/*
 *  Likewise, this is our part of the database handle, as returned
 *  by DBI->connect. We receive the handle as an "SV*", say "dbh",
 *  and receive a pointer to the structure below by declaring
 *
 *    D_imp_dbh(dbh);
 *
 *  This declares a variable called "imp_dbh" of type
 *  "struct imp_dbh_st *".
 */
struct imp_dbh_st {
    dbih_dbc_t com;         /*  MUST be first element in structure   */
};


/*
 *  Finally our part of the statement handle. We receive the handle as
 *  an "SV*", say "dbh", and receive a pointer to the structure below
 *  by declaring
 *
 *    D_imp_sth(sth);
 *
 *  This declares a variable called "imp_sth" of type
 *  "struct imp_sth_st *".
 */
struct imp_sth_st {
    dbih_stc_t com;       /* MUST be first element in structure     */
};

#endif  /* DBD_CSV_CSV_H */
