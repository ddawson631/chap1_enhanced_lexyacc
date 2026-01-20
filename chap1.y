%{
//Generate a parser to perform the actions associated with the grammar rules described below.
#include "ch1_info.h"
EXPLIST nilEL=0;
NAMELIST nilNL=0;
NUMTYP n;
BOOLEAN interactive;

int yylex();
void yyerror(const char *s);
%}

//Declare the types used for symbols in yacc rules below.
//They are specified in angle brackets in %token and %type directives that follow.
//The values and data structures that these types represent are used to build an AST
//that represents the fundef or expr that was input.
%union
{
    NAMEINDEX nameIndex;    //an index in the printNames array 
    NUMTYP num;             //a NUMBER token (see %token below)
    EXP e;                  //a VALEXP, VAREXP or APEXP structure
    EXPLIST eL;             //a structure for a list of EXPs
    FUNDEF fd;              //a function definition structure
    NAMELIST nl;            //a structure for a list of nameIndexes
}

%define lr.type ielr       //Bison manual indicates that type=ielr is best when error=detailed.
%define parse.lac full     //Bison manual says lac=full avoids inaccurate info when error=detailed. 
%define parse.error detailed   //Allows yyerror messages to report the token it expected.

//Define tokens that are made of multiple characters.
//The patterns that they represent are defined in the lexer spec.
//The ERROR token is an exception. It has no pattern defined in the lexer.
//And since it is not a part of any grammar rule defined below, returning it from the lexer causes
//a syntax error which triggers a call to yyerror() and a transfer of control to the error rule
//defined below. When lexer action code detects certain semantic errors (err_range, err_name_len,
//err_max_names), it returns this ERROR token to trigger yyerror() and the error rule.
//For these 3 semantic errors, you will see both a message from errmsg() and yyerror().
%token <nameIndex> NAME
%token <num>  NUMBER
%token ASSIGN IF THEN ELSE FI WHILE DO OD SEQ QES FUN NUF ERROR

//Declare Associativity and Precedence. The order of the following lines determine precedence
//from lowest to highest. So ';' and ',' have lowest precedence. 
//'*' and '/' have highest precedence among the binary operators.
//UPLUS & UMINUS tags are used to give unary '+' and '-' the highest precedence of all. 
%left ';' ','
%right ASSIGN
%left PRINT
%left '<' '=' '>'
%left '-' '+'
%left '*' '/'
%nonassoc UPLUS
%nonassoc UMINUS
//Note that the precedence of parentheses was not declared. 
//Per perplexity.ai, the parentheses rule, under exp rules below, effectively gets the
//highest precedence "by its nature" since it causes the parser to reduce the enclosed expression
//before applying other operations outside the parentheses.

//Declare types of all LHS symbols in yacc rules.
%type <e> expr exp ifex whileex seqex;
%type <eL> expr_list arg_list arg_list_tail;
%type <nameIndex> fundef;
%type <nl> param_list param_list_tail;

//Below are the yacc rules and their actions (C code in braces).
//The actions are executed by the parser when the input matches a rule.
//Regarding rule symbols, nonterminals are in lowercase, terminals are in uppercase or single quotes. 
//The actions build an AST for the expr or fundef that was input.
//The start rule evaluates that AST by passing it to eval() then displays its result. 
//The actions refer to symbols $$, $1, $2, $3, etc.
//$$ represents the symbol on the LHS of the colon.
//$1, $2, $3, ... respectively represent the symbols on the RHS of the colon.

%%
//input → expr | fundef
//This is the start rule for our parser.
//It expects an input line to be either an expr or fundef terminated by a $.
//$ is the end of input marker.
//The recursive use of stmt_list on the RHS allows multiple input lines to be entered.
stmt_list:    /* empty */
         |    stmt_list expr '$'   { //if no error then evaluate the expr that was input 
                                     // and display its value
                                      if (!error)
                                          n = eval($2, emptyEnv());  //eval $2 (expr AST) 

                                      if (!error)
                                      {
                                          prValue(n);       //display expr value
                                          printf("\n\n");
                                      }                                   
                                      setError(false, "stmt_list stmt"); //reset global error flag false
                                      if (!readfile) printf(PROMPT); //display prompt if not reading file 
                                   }
//The result of a fundef is to display the function name.
//Its logic is not evaluated until a function call occurs in an expr.
         |    stmt_list fundef '$' { //if no error then display function name of fundef
                                      if (!error)
                                      {
                                          prName($2);      //display function name
                                          printf("\n\n");
                                      }
                                      setError(false, "stmt_list stmt");
                                      if (!readfile) printf(PROMPT);
                                   }

//When the parser encounters a syntax error, yyerror is called and control returns to the
//action for this special error token. The $ (end of input marker) is the synchronizing token.
//The parser will skip chars in the input stream until it reads the next $ then it will resume
//normal parsing of the next input.
         |    error '$' {
                           yyclearin; // discard lookahead
                           yyerrok;   // clear the error state
                           setError(false, "stmt_list error"); //reset error flag false
                           if (readfile)
                               printf("\n"); //blank line after an error for readability in output
                           else
                               printf(PROMPT); //prompt for next input if not reading a file
                        }
         ;

//fundef → fun name ( param_list ) := expr nuf
//When a function def is evaluated, the result is to display the name of the defined function.
//So the line $$ = $2 in the action assigns value of NAME to the fundef symbol on the LHS. 
fundef: FUN NAME '(' param_list ')' ASSIGN expr NUF {
                                                      newDef($2, $4, $7); //create a new function def
                                                                          //from $2 (NAME), 
                                                                          //$4 (param_list),
                                                                          //$7 (expr) which represents
                                                                          //the body of the function.
                                                      $$ = $2;  //fundef = NAME
                                                    }
      ;


//The param_list rule defines a list of NAMES.
//It can be empty, a single NAME or a list of NAMEs separated by commas. 
//It disallows a list that ends with a comma due to how param_list_tail is structured.
//When param_list_tail is empty, the list ends.
param_list: /* empty */ { $$ = nilNL; }
          | NAME param_list_tail { $$ = mkNamelist($1, $2); }
          ;

param_list_tail: /* empty */ { $$ = nilNL; }
               | ',' NAME param_list_tail { $$ = mkNamelist($2, $3); }
               ;

//The arg_list rule defines a list expressions. 
//It can be empty, a single expression or a list of expressions separated by commas.
//It disallows a list that ends with a comma due to how arg_list_tail is structured.
//When arg_list_tail is empty, the list ends.
arg_list: /* empty */ { $$ = nilEL; }
        | expr arg_list_tail { $$ = mkExplist($1, $2); }
        ;

arg_list_tail: /* empty */ { $$ = nilEL; }
             | ',' expr arg_list_tail { $$ = mkExplist($2, $3); }
             ;


//ifex → if e1 then e2 else e3 fi
ifex:   IF expr THEN expr ELSE expr FI
        { $$ = mkAPEXP(ifsy_index, mkExplist($2, mkExplist($4, mkExplist($6,nilEL)))); }
    ;

//whileex → while e1 do e2 o
whileex: WHILE expr DO expr OD
         { $$ = mkAPEXP(whilesy_index, mkExplist($2, mkExplist($4,nilEL))); }
       ;

//seqex → seq expr_list qes
seqex:  SEQ expr_list QES { $$ = mkAPEXP(seqsy_index, $2); }
     ;

//expr_list → expr [ ; expr ]*
expr_list: expr  { $$ = mkExplist($1, nilEL); }
         | expr ';' expr_list { $$ = mkExplist($1, $3); }
         ;

//expr → ifex | whileex | seqex | exp
expr:    ifex              { $$ = $1; }
    |    whileex           { $$ = $1; }
    |    seqex             { $$ = $1; }
    |    exp               { $$ = $1; }
    ;
//For a binary op, we make an APEXP that applies it to the left ($1) and right ($3) operands.
exp:    exp '+' exp { $$ = mkAPEXP(addsy_index, mkExplist($1, mkExplist($3,nilEL))); }
   |    exp '-' exp { $$ = mkAPEXP(subsy_index, mkExplist($1, mkExplist($3,nilEL))); }
   |    exp '*' exp { $$ = mkAPEXP(mulsy_index, mkExplist($1, mkExplist($3,nilEL))); }
   |    exp '/' exp { $$ = mkAPEXP(divsy_index, mkExplist($1, mkExplist($3,nilEL))); }
   |    exp '<' exp { $$ = mkAPEXP( lssy_index, mkExplist($1, mkExplist($3,nilEL))); }
   |    exp '=' exp { $$ = mkAPEXP( eqsy_index, mkExplist($1, mkExplist($3,nilEL))); }
   |    exp '>' exp { $$ = mkAPEXP( gtsy_index, mkExplist($1, mkExplist($3,nilEL))); }
   |    PRINT exp   { $$ = mkAPEXP(printsy_index, mkExplist($2, nilEL)); }
//For unary minus, we make an APEXP that multiplies the exp by -1
   |    '-' exp %prec UMINUS { $$ = mkAPEXP(mulsy_index, mkExplist(mkVALEXP(-1), mkExplist($2,nilEL))); }
   |    '+' exp %prec UPLUS  { $$ = $2; }
   |    NUMBER        { $$ = mkVALEXP($1); }
//exp1 → exp2 [ :=  exp1 ]*
//When the assignment rule is matched, the action makes an APEXP for the assignment operator.
//When evaluated, the APEXP assigns the value of the exp ($3) to a VAREXP for the NAME ($1). 
   |    NAME ASSIGN exp   { $$ = mkAPEXP(assignsy_index, mkExplist(mkVAREXP($1), mkExplist($3,nilEL))); }
//funcall → name ( arglist )
//make an APEXP that applies the function name ($1) to an Explist ($3) containing the arguments.
   |    NAME '(' arg_list ')' { $$ = mkAPEXP($1, $3); }
//variable name - make a VAREXP for the NAME. When evaluated, it returns value assigned to the variable.
   |    NAME          { $$ = mkVAREXP($1); }
//parentheses - assign the value of the parenthesized exp on RHS to the LHS.
//This has the effect of evaluating the operations inside parentheses before those outside.
   |    '(' exp ')'   { $$ = $2; }
   ;
%%
int main()
{
    initNames();
    globalEnv = emptyEnv();

//Indicate to the lexer whether the program is run in interactive or batch mode
//When lexer sees EOF, interactive mode will prompt for next input but batch mode will exit program.
    if (isatty(fileno(stdin))) {
        printf("Input from terminal (interactive mode)\n");
        interactive = true;
    } else {
        printf("Input from pipe/file (batch mode)\n");
        interactive = false;
    }

    printf(PROMPT);
    fflush(stdout);
    yyparse();  //perform the REPL until quit is input or EOF in batch mode
}
