//---------------------------
//        DECLARATIONS
//---------------------------
#define _POSIX_C_SOURCE 200809L
#include <ctype.h>
#include <errno.h>
#include <limits.h>
#include <setjmp.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define NAMELENG 20 // Max length of a name

#ifdef TESTSIZE
#define MAXNAMES 28 // Max no. of names to test err_max_names
#else
#define MAXNAMES 100 // Max number of different names
#endif

#define ARGLENG 40 // Maximum length of a command argument

#define PROMPT "-> " // initial prompt
#define PROMPT2 "> " // continuation prompt

typedef short int NAMESIZE;
typedef char *NAMESTRING;
typedef short int NAMEINDEX; // an index in printNames array

typedef long long NUMTYP;
typedef short int ARGSIZE;

typedef enum
{
    false,
    true
} BOOLEAN;

typedef enum
{
    IFOP = 1,
    WHILEOP,
    ASSIGNOP,
    SEQOP,
    ADDOP,
    SUBOP,
    MULOP,
    DIVOP,
    EQOP,
    LTOP,
    GTOP,
    PRINTOP
} BUILTINOP;

typedef enum
{
    nameidsy = 1,
    numsy,
    funidsy,
    ifsy,
    thensy,
    elsesy,
    fisy,
    whilesy,
    dosy,
    odsy,
    seqsy,
    qessy,
    funsy,
    nufsy,
    assignsy,
    rparsy,
    lparsy,
    semsy,
    comsy,
    addsy,
    subsy,
    mulsy,
    divsy,
    eqsy,
    lssy,
    gtsy,
    printsy,
    quitsy,
    dollarsy
} TOKEN;

typedef enum
{
    err_cwd = 1,
    err_open,
    err_max_names,
    err_name_len,
    err_num_args,
    err_undef_func,
    err_num_args2,
    err_undef_var,
    err_undef_op,
    err_nested_load,
    err_div_zero,
    err_range
} ERROR_NUM; // error codes passed to errmsg()

typedef struct EXPREC *EXP;
typedef struct EXPLISTREC *EXPLIST;
typedef struct ENVREC *ENV;
typedef struct VALUELISTREC *VALUELIST;
typedef struct NAMELISTREC *NAMELIST;
typedef struct FUNDEFREC *FUNDEF;

enum EXPTYPE
{
    VALEXP,
    VAREXP,
    APEXP
};

struct EXPREC
{
    enum EXPTYPE etype;
    union {
        NUMTYP num;
        NAMEINDEX varble;
        struct
        {
            NAMEINDEX optr;
            EXPLIST args;
        } ap;
    } u;
};

struct EXPLISTREC
{
    EXP head;
    EXPLIST tail;
};

struct VALUELISTREC
{
    NUMTYP head;
    VALUELIST tail;
};

struct NAMELISTREC
{
    NAMEINDEX head;
    NAMELIST tail;
};

struct ENVREC
{
    NAMELIST vars;
    VALUELIST values;
};

struct FUNDEFREC
{
    NAMEINDEX funname;
    NAMELIST formals;
    EXP body;
    FUNDEF nextfundef;
};

extern BOOLEAN readfile, error;
extern NAMEINDEX addsy_index, subsy_index, mulsy_index, divsy_index, eqsy_index, lssy_index,
    gtsy_index, ifsy_index, whilesy_index, assignsy_index, seqsy_index, printsy_index;
extern ENV globalEnv;
extern char *null_str;
extern int null_int;
extern NAMESTRING printNames[MAXNAMES + 1];

//---------------------------
// DATA STRUCTURE OPERATIONS
//---------------------------
EXP mkVALEXP(NUMTYP);
EXP mkVAREXP(NAMEINDEX);
EXP mkAPEXP(NAMEINDEX, EXPLIST);
EXPLIST mkExplist(EXP, EXPLIST);
NAMELIST mkNamelist(NAMEINDEX, NAMELIST);
VALUELIST mkValuelist(NUMTYP, VALUELIST);
ENV mkEnv(NAMELIST, VALUELIST);
void prEnv(ENV);
int lengthVL(VALUELIST);
int lengthNL(NAMELIST);
void prExp(EXP);
void prExplist(EXPLIST);

//-----------------
// NAME MANAGEMENT
//-----------------
FUNDEF fetchDef(NAMEINDEX);
void newDef(NAMEINDEX, NAMELIST, EXP);
void initNames(void);
void prName(NAMEINDEX);
void prUserList(void);
NAMEINDEX install(char *);

//-----------------
// ERROR MESSAGES
//-----------------

void setError(BOOLEAN, char *);
void errmsg(ERROR_NUM, char *, int);

//--------------
// ENVIRONMENTS
//--------------
ENV emptyEnv(void);
void bindVar(NAMEINDEX, NUMTYP, ENV);
VALUELIST findVar(NAMEINDEX, ENV);
void assign(NAMEINDEX, NUMTYP, ENV);
NUMTYP fetch(NAMEINDEX, ENV);
int isBound(NAMEINDEX, ENV);

//---------
// NUMBERS
//---------
void prValue(NUMTYP);
int arity(BUILTINOP);
NUMTYP applyValueOp(BUILTINOP, VALUELIST);

//------------
// EVALUATION
//------------

VALUELIST evalList(EXPLIST, ENV);
NUMTYP applyUserFun(NAMEINDEX, VALUELIST);
NUMTYP applyCtrlOp(BUILTINOP, EXPLIST, ENV);
NUMTYP eval(EXP, ENV);
