//---------------------------
//       DECLARATIONS
//---------------------------

#include "ch1_info.h"

FUNDEF fundefs;
NUMTYP numval;
ENV globalEnv;
EXP currentExp;

NAMESTRING printNames[MAXNAMES + 1]; // built-in & user-defined names

char punctop[] = "()+-*/:=<>;,$!"; // punctuation and operator chars
char *null_str = NULL;             // default string passed to errmsg()
int null_int = 0;                  // default int passed to errmsg()

NAMEINDEX numNames, numBuiltins, addsy_index, subsy_index, mulsy_index, divsy_index, eqsy_index,
    lssy_index, gtsy_index, ifsy_index, whilesy_index, assignsy_index, seqsy_index, printsy_index,
    // initNames() saves index of first/last ControlOp & ValueOp
    // in following variables for checking which range Op is in.
    firstValueOp, lastValueOp, firstControlOp, lastControlOp;

BOOLEAN quittingtime = false, // true = exit the program.
    readfile = false,         // true = read input from file instead of terminal.
    error = false;            // true = an error occurred. See setError().

//---------------------------
// DATA STRUCTURE OPERATIONS
//---------------------------

// mkVALEXP - return an EXP of type VALEXP with num n
EXP mkVALEXP(NUMTYP n)
{
    EXP e;

    e = malloc(sizeof(struct EXPREC));
    e->etype = VALEXP;
    e->u.num = n;
    return e;
} // mkVALEXP

// mkVAREXP - return an EXP of type VAREXP with varble nm
EXP mkVAREXP(NAMEINDEX nm)
{
    EXP e;

    e = malloc(sizeof(struct EXPREC));
    e->etype = VAREXP;
    e->u.varble = nm;
    return e;
} // mkVAREXP

// mkAPEXP - return EXP of type APEXP with optr op and args el
EXP mkAPEXP(NAMEINDEX op, EXPLIST el)
{
    EXP e;

    e = malloc(sizeof(struct EXPREC));
    e->etype = APEXP;
    e->u.ap.optr = op;
    e->u.ap.args = el;
    return e;
} // mkAPEXP

// mkExplist - return an EXPLIST with head e and tail el
EXPLIST mkExplist(EXP e, EXPLIST el)
{
    EXPLIST newel;

    newel = malloc(sizeof(struct EXPLISTREC));
    newel->head = e;
    newel->tail = el;
    return newel;
} // mkExplist

// mkNamelist - return a NAMELIST with head n and tail nl
NAMELIST mkNamelist(NAMEINDEX nm, NAMELIST nl)
{
    NAMELIST newnl;

    newnl = malloc(sizeof(struct NAMELISTREC));
    newnl->head = nm;
    newnl->tail = nl;
    return newnl;
} // mkNamelist

// mkValuelist - return an VALUELIST with head n and tail vl
VALUELIST mkValuelist(NUMTYP n, VALUELIST vl)
{
    VALUELIST newvl;

    newvl = malloc(sizeof(struct VALUELISTREC));
    newvl->head = n;
    newvl->tail = vl;
    return newvl;
}

// mkEnv - return an ENV with vars nl and values vl
// Author Samuel Kamin uses Greek letter rho to refer to an ENV in the mathematical description
// in his textbook. So he uses variable rho for an ENV throughout this source code.
ENV mkEnv(NAMELIST nl, VALUELIST vl)
{
    ENV rho;

    rho = malloc(sizeof(struct ENVREC));
    rho->vars = nl;
    rho->values = vl;
    return rho;
} // mkEnv

// prEnv - print vars & values in an ENV
void prEnv(ENV env)
{

    NAMELIST nl;
    VALUELIST vl;

    int i;

    i = 0;
    nl = env->vars;
    vl = env->values;

    while (nl != 0)
    {
        i = i + 1;
        printf("%d.  %s = %lld", i, printNames[nl->head], vl->head);
        nl = nl->tail;
        vl = vl->tail;
    }
} // prEnv

// lengthVL - return length of VALUELIST vl
int lengthVL(VALUELIST vl)
{
    int i;

    i = 0;
    while (vl != 0)
    {
        i = i + 1;
        vl = vl->tail;
    }
    return i;
} // lengthVL

// lengthNL - return length of NAMELIST nl
int lengthNL(NAMELIST nl)
{
    int i;

    i = 0;
    while (nl != 0)
    {
        i = i + 1;
        nl = nl->tail;
    }
    return i;
} // lengthNL

void prExplist(EXPLIST); // forward declaration

// print an EXP
void prExp(EXP e)
{
    switch (e->etype)
    {
    case VALEXP:
        printf("etype = VALEXP\n");
        printf("  num = %lld\n", e->u.num);
        break;

    case VAREXP:
        printf(" etype = VAREXP\n");
        printf("varble = %s\n", printNames[e->u.varble]);
        break;

    case APEXP:
        printf(" etype = APEXP\n");
        printf("  optr = %s\n", printNames[e->u.ap.optr]);
        prExplist(e->u.ap.args);
        break;

    default:
        printf("Invalid etype = %d", e->etype);
        break;
    }
}

// prExplist - print an Explist
void prExplist(EXPLIST el)
{
    prExp(el->head);

    if (el->tail != 0)
        prExplist(el->tail);
    return;
} // prExplist

//-----------------
// NAME MANAGEMENT
//-----------------

// fetchDef - get FUNCTION definition of fname from fundefs
FUNDEF fetchDef(NAMEINDEX fname)
{
    FUNDEF f;
    BOOLEAN found;

    found = false;
    f = fundefs;
    while (f != 0 && !found)
        if (f->funname == fname)
            found = true;
        else
            f = f->nextfundef;
    return f;
} // fetchDef

// newDef - add new FUNCTION fname with parameters nl, body e
void newDef(NAMEINDEX fname, NAMELIST nl, EXP e)
{
    FUNDEF f;

    f = fetchDef(fname);
    if (f == 0) // fname not yet defined as a FUNCTION
    {
        f = malloc(sizeof(struct FUNDEFREC));
        f->nextfundef = fundefs; // place new FUNDEFREC
        fundefs = f;             // at front of fundefs list
    }
    f->funname = fname;
    f->formals = nl;
    f->body = e;
} // newDef

// initNames - place all pre-defined (built in) names into printNames
//             user-defined names (functions, variables) will also be kept here
void initNames()
{
    int i;

    fundefs = 0; // empty list of fundefs

    ifsy_index = firstControlOp = i = IFOP; // IFOP==1
    printNames[i] = "if";

    i = i + 1;
    whilesy_index = i;
    printNames[i] = "while";

    i = i + 1;
    assignsy_index = i;
    printNames[i] = ":=";

    i = i + 1;
    seqsy_index = lastControlOp = i;
    printNames[i] = "seq";

    i = i + 1;
    // The index of next few operators is saved for use in building
    // the associated APEXP in yacc rule actions in chap1.y

    addsy_index = firstValueOp = i;
    printNames[i] = "+";

    i = i + 1;
    subsy_index = i;
    printNames[i] = "-";

    i = i + 1;
    mulsy_index = i;
    printNames[i] = "*";

    i = i + 1;
    divsy_index = i;
    printNames[i] = "/";

    i = i + 1;
    eqsy_index = i;
    printNames[i] = "=";

    i = i + 1;
    lssy_index = i;
    printNames[i] = "<";

    i = i + 1;
    gtsy_index = i;
    printNames[i] = ">";

    i = i + 1;
    printsy_index = lastValueOp = i;
    printNames[i] = "print";

    i = i + 1;
    printNames[i] = "quit";

    i = i + 1;
    printNames[i] = "then";

    i = i + 1;
    printNames[i] = "else";

    i = i + 1;
    printNames[i] = "fi";

    i = i + 1;
    printNames[i] = "do";

    i = i + 1;
    printNames[i] = "od";

    i = i + 1;
    printNames[i] = "qes";

    i = i + 1;
    printNames[i] = "fun";

    i = i + 1;
    printNames[i] = "nuf";

    i = i + 1;
    printNames[i] = "(";

    i = i + 1;
    printNames[i] = ")";

    i = i + 1;
    printNames[i] = ";";

    i = i + 1;
    printNames[i] = ",";

    i = i + 1;
    printNames[i] = "$";

    numNames = numBuiltins = i - IFOP + 1; // no. of entries so far
} // initNames

// prName - print name nm
void prName(NAMEINDEX nm)
{
    printf("%s", printNames[nm]);
} // prName

// prUserList - List user-defined names and token symbol id (for debugging)
void prUserList()
{
    int i;

    for (i = numBuiltins + 1; i <= numNames; i++)
    {
        printf("printNames[%d]= ", i);
        prName(i);
        printf("\n");
    }
} // prUserList

// install - insert new name into printNames
//         - return its index in printNames array
NAMEINDEX install(char *nm)
{
    NAMEINDEX i;
    int result;
    BOOLEAN found;

    i = firstControlOp;
    found = false;
    result = 0;

    while (i <= numNames && !found)
    {
        result = strcmp(nm, printNames[i]);

        if (!result)
            found = true;
        else
            i = i + 1;
    }

    if (!found)
    {
        if (i > MAXNAMES)
        {
            errmsg(err_max_names, null_str, null_int);
            return 0;
        }
        else // insert new name
        {
            printNames[i] = malloc(strlen(nm) + 1);
            numNames = i;
            strcpy(printNames[i], nm); 
        }
    }

    return i; // return index of name
} // install

//-----------------
// ERROR MESSAGES
//-----------------

// setError - set value of global variable error to true or false.
// The location variable indicates which rule or function called
// setError() for debugging purposes.
// It is initialized to false and is set to true in errmsg() and yyerror().
// If true then the stmt_list rule in chap1.y does not print a result.
// This avoids printing the previous valid stmt value as the result of an
// erroneous stmt.
// It is reset to false in the stmt_list rule actions prior to printing
// the prompt for the next input.
void setError(BOOLEAN boolval, char *location)
{
    // printf("*** setError: error = %s at %s\n", (boolval?"true":"false"), location);
    error = boolval;
}

// errmsg - display error message for given error number
void errmsg(ERROR_NUM errnum, char *err_str, int err_int)
{
    printf("\n***** ");
    switch (errnum)
    {
    case err_cwd:
        perror("getcwd() error");
        break;
    case err_open:
        printf("filename= %s\n", err_str);
        perror("fopen() error");
        break;
    case err_max_names:
        printf("No more room for names");
        break;
    case err_name_len:
        printf("Name exceeds %d chars, begins: %s", err_int, err_str);
        break;
    case err_num_args:
        printf("Wrong number of arguments to ");
        prName(err_int);
        printf("\nFatal error by developer. Exiting program.\n");
        exit(1);
        break;
    case err_undef_func:
        printf("Undefined function: ");
        prName(err_int);
        printf("\n");
        break;
    case err_num_args2:
        printf("Wrong number of arguments to: ");
        prName(err_int);
        printf("\n");
        break;
    case err_undef_var:
        printf("Undefined variable: ");
        prName(err_int);
        break;
    case err_undef_op:
        printf("eval: invalid value for op = %d", err_int);
        break;
    case err_nested_load:
        printf("Load commands cannot occur inside a file being loaded.\n");
        printf("Remove the load command for file %s\n", err_str);
        break;
    case err_div_zero:
        printf("applyValueOp: divide by zero\n");
        break;
    case err_range:
        printf("%s is out of range.\n", err_str);
        printf("It must be between %lld and %lld, inclusive.", LLONG_MIN, LLONG_MAX);
        break;
    default:
        break;
    }
    printf("\n");
    setError(true, "errmsg()");
} // errmsg

//--------------
// ENVIRONMENTS
//--------------

// emptyEnv - return an environment with no bindings
ENV emptyEnv()
{
    return mkEnv(0, 0);
} // emptyEnv

// bindVar - bind variable nm to value n in environment rho
void bindVar(NAMEINDEX nm, NUMTYP n, ENV rho)
{
    rho->vars = mkNamelist(nm, rho->vars);
    rho->values = mkValuelist(n, rho->values);
} // bindVar

// findVar - look up nm in rho
VALUELIST findVar(NAMEINDEX nm, ENV rho)
{
    NAMELIST nl;
    VALUELIST vl;
    BOOLEAN found;

    found = false;
    nl = rho->vars;
    vl = rho->values;
    while (nl != 0 && !found)
    {
        if (nl->head == nm)
            found = true;
        else
        {
            nl = nl->tail;
            vl = vl->tail;
        }
    }
    return vl;
} // findVar

// assign - assign value n to variable nm in rho
void assign(NAMEINDEX nm, NUMTYP n, ENV rho)
{
    VALUELIST varloc;

    varloc = findVar(nm, rho);
    varloc->head = n;
} // assign

// fetch - return number bound to nm in rho
NUMTYP fetch(NAMEINDEX nm, ENV rho)
{
    VALUELIST vl;

    vl = findVar(nm, rho);
    return vl->head;
} // fetch

// isBound - check if nm is bound in rho
int isBound(NAMEINDEX nm, ENV rho)
{
    return findVar(nm, rho) != 0;
} // isBound

//---------
// NUMBERS
//---------

// prValue - print number n
void prValue(NUMTYP n)
{
    printf("%lld", n);
}

// arity - return number of arguments expected by op
int arity(BUILTINOP op)
{
    if (op >= ADDOP && op <= GTOP)
        return 2;
    else
        return 1;
} // arity

// applyValueOp - apply operator to arguments in VALUELIST
NUMTYP applyValueOp(BUILTINOP op, VALUELIST vl)
{
    NUMTYP n, n1, n2;

    if (arity(op) != lengthVL(vl))          //Check if developer erred in building an APEXP.
        errmsg(err_num_args, null_str, op); //It is a fatal error and should never occur.

    n1 = vl->head; // 1st actual
    if (arity(op) == 2)
        n2 = vl->tail->head; // 2nd actual

    switch (op)
    {
    case ADDOP:
        n = n1 + n2;
        break;
    case SUBOP:
        n = n1 - n2;
        break;
    case MULOP:
        n = n1 * n2;
        break;
    case DIVOP:
        if (n2 == 0)
        {
            errmsg(err_div_zero, null_str, null_int);
            n = 0;
        }
        else
            n = n1 / n2;
        break;
    case EQOP:
        if (n1 == n2)
            n = 1;
        else
            n = 0;
        break;
    case LTOP:
        if (n1 < n2)
            n = 1;
        else
            n = 0;
        break;
    case GTOP:
        if (n1 > n2)
            n = 1;
        else
            n = 0;
        break;
    case PRINTOP:
        prValue(n1);
        printf("\n");
        n = n1;
        break;
    default: // this case should never occur
        printf("applyValueOp: bad value for op = %d\n", op);
        break;
    } // switch

    return n;
} // applyValueOp

//------------
// EVALUATION
//------------

NUMTYP eval(EXP, ENV); // forward declaration

// evalList - evaluate each expression in el
VALUELIST evalList(EXPLIST el, ENV rho)
{
    NUMTYP h;
    VALUELIST t;

    if (el == 0)
        return 0;
    else
    {
        h = eval(el->head, rho);
        t = evalList(el->tail, rho);
        return mkValuelist(h, t);
    }
} // evalList

// applyUserFun - look up definition of nm and apply to actuals
NUMTYP applyUserFun(NAMEINDEX nm, VALUELIST actuals)
{
    FUNDEF f;
    ENV rho;

    f = fetchDef(nm);
    if (f == 0)
    {
        errmsg(err_undef_func, null_str, nm);
        return 0;
    }

    if (lengthNL(f->formals) != lengthVL(actuals))
    {
        errmsg(err_num_args2, null_str, nm);
        return 0;
    }
    else
    {
        rho = mkEnv(f->formals, actuals);
        return eval(f->body, rho);
    }
} // applyUserFun

// applyCtrlOp - apply CONTROLOP op to args in rho
NUMTYP applyCtrlOp(BUILTINOP op, EXPLIST args, ENV rho)
{
    NUMTYP n=0;

    switch (op)
    {
    case IFOP:
        if (eval(args->head, rho))
            n = eval(args->tail->head, rho);
        else
            n = eval(args->tail->tail->head, rho);
        break;
    case WHILEOP:
        n = eval(args->head, rho);
        while (n)
        {
            n = eval(args->tail->head, rho);
            n = eval(args->head, rho);
        }
        break;
    case ASSIGNOP:
        n = eval(args->tail->head, rho);
        if (isBound(args->head->u.varble, rho))
            assign(args->head->u.varble, n, rho);
        else if (isBound(args->head->u.varble, globalEnv))
            assign(args->head->u.varble, n, globalEnv);
        else
            bindVar(args->head->u.varble, n, globalEnv);
        break;
    case SEQOP:
        while (args->tail != 0)
        {
            n = eval(args->head, rho);
            args = args->tail;
        }
        n = eval(args->head, rho); // value of last statement in seq
        break;
    default:
        printf("applyCtrlOp: bad value for op = %d\n", op);
        break;
    } // switch

    return n;
} // applyCtrlOp

// eval - return value of expression e in local environment rho
NUMTYP eval(EXP e, ENV rho)
{
    BUILTINOP op;
    NUMTYP n=0;

    switch (e->etype)
    {
    case VALEXP:
        n = e->u.num;
        break;
    case VAREXP:
        if (isBound(e->u.varble, rho))
            n = fetch(e->u.varble, rho);
        else if (isBound(e->u.varble, globalEnv))
            n = fetch(e->u.varble, globalEnv);
        else
            errmsg(err_undef_var, null_str, e->u.varble);
        break;
    case APEXP:
        op = e->u.ap.optr;
        if (op > numBuiltins)
            n = applyUserFun(op, evalList(e->u.ap.args, rho));
        else
        {
            if (op >= firstControlOp && op <= lastControlOp)
                n = applyCtrlOp(op, e->u.ap.args, rho);
            else if (op >= firstValueOp && op <= lastValueOp)
                n = applyValueOp(op, evalList(e->u.ap.args, rho));
            else
                errmsg(err_undef_op, null_str, op);
        }
        break;
    default:
        printf("Invalid etype = %d", e->etype);
        break;
    } // switch

    if (error) // errmsg() & yyerror set error==true
        n = 0; // set return value to 0 during errors

    return n;
} // eval
