%{
/*
  Generate a lexer to read the input stream and perform the associated
  actions for the patterns described below.
  Some actions only return a token to the parser.
  Others run C code before returning, e.g. to install a name in the
  symbol table before returning the NAME token.
  Others don't return to the parser. E.g. for \n, lineNo is incremented and
  a prompt displayed before the lexer reads the next input.
  Or for a load command, a file is opened and the lexer begins reading from it.
*/

#include "ch1_info.h"
#include "chap1.tab.h"

/*
  if not reading stdin and echo is true then echo all chars read.
  echo is set true for a load file command and reset false at EOF.
*/
#define YY_USER_ACTION \
        if (yyin != stdin && echo) { \
            printf("%s", yytext); \
        }
        
char *filename, *endptr;
FILE *infile;
int lineNo = 0;
BOOLEAN echo = false;
char cwd[PATH_MAX];
extern BOOLEAN interactive;

/*
  When lex detects an error, it calls yyerror() which returns control to 
  the error rule in the parser. A few actions below return an ERROR token which
  is not a valid token in the grammar. This causes the parser to call yyerror()
  and give control to the error rule. My own version of yyerror() is defined
  at bottom of this file.
*/
void yyerror(const char *);
%}

/* prevent call to yywrap() to read another file at EOF */
%option noyywrap  

/* exclusive state for matching a file name */
%x fname          

%%
"quit"             { printf("\nquitting\n"); return 0; }

^")user"           { prUserList(); }

^")load "          { BEGIN(fname); echo = true; }
^")sload "         { BEGIN(fname); echo = false; }

 /*
  Match a filename as part of a load or sload command. 
  Open the file and set up the lexer to begin reading from it.
 */
<fname>[^\t\n]+    {    // match filename - any chars except tab & newline
                       BEGIN(INITIAL);  // reset INITIAL, unset fname state 
                       filename = strdup(yytext); 

                       if (!readfile) // if not already reading a file 
                       {
                           // open file and prepare to read from it
                           infile = fopen(filename,"r");
                           if (!infile)
                           {
                               errmsg(err_open, filename, null_int); //sets error=true
                               if (interactive)
                               {
                                   yyrestart(stdin);
                                   setError(false, "open error"); //reset error=false
                                   printf(PROMPT); //prompt for next input
                               }
                               else
                                   return 0; // batch mode - exit
                           }   
                           else
                           {
                               // create buffer for it and switch to it
                               yyin = infile;
                               yy_switch_to_buffer(yy_create_buffer(yyin, YY_BUF_SIZE));
                               readfile = true;
                               lineNo = 0;
                               if (getcwd(cwd, sizeof(cwd)) != NULL)
                               {
                                   printf("\nCurrent Directory is: %s\n\n", cwd);
                                   printf(" Loading file : %s\n\n", filename);
                               }
                               else
                               {
                                   errmsg(err_cwd, null_str, null_int);
                                   yyrestart(stdin);
                                   setError(false, "cwd error"); //reset error=false
                                   printf(PROMPT); //prompt for next input
                               }
                           }
                       }
                       else //file already open - nested load cmds not allowed
                       {
                           errmsg(err_nested_load, filename, null_int);
                           fclose(yyin);
                           return 0; // quit program
                       }

                   }
                   
"if"    { return IF;    }
"then"  { return THEN;  }
"else"  { return ELSE;  }
"fi"    { return FI;    }
"while" { return WHILE; }
"do"    { return DO;    }
"od"    { return OD;    }
"seq"   { return SEQ;   }
"qes"   { return QES;   }
"fun"   { return FUN;   }
"nuf"   { return NUF;   }
"print" { return PRINT; }

!.*     ;  // ignore comments

"$".*\n   { // match $ (the end of input marker) and ignore any chars that follow it.
            lineNo++;
            return '$';
          }

\n      { //at end of line, increment lineNo, display prompt if not reading file
          lineNo++; 
          if (!readfile)
          {
              if (error)
              {
                  printf(PROMPT);  // restart input at initial prompt after error
                  setError(false, "lex action for newline");
              }
              else
                  printf(PROMPT2); // continuation prompt
          }
        }

[ \t]   ;  // ignore white space

 /*
  Match a number as a sequence of digits followed by a delimiter.
  Digits followed by a nondelimiter will be matched as a name in next pattern below. 
  The trailing context lists the delimiters. 
  After adding tab, newline, carriage return to the list, I decided to include the 
  full range of ASCII control chars plus the delete char. 
 */
[0-9]+/[();+\-*/:=<>,$! \t\n\r\x00-\x1F\x7F] {
                                               errno = 0;
                                               yylval.num = strtoll(yytext, &endptr, 10);
                                               if ((yylval.num == LONG_MAX || yylval.num == LONG_MIN)
                                                    && errno == ERANGE)
                                               {
                                                   errmsg(err_range, yytext, null_int);
                                                   return ERROR; //trigger yyerror in parser
                                               }
                                               else
                                                   return NUMBER;
                                             }

 /*
  Match a name as any sequence of chars that is not a number (matched above) and 
  does not contain a delimiter. This includes a sequence of digits that contain nondelimiters. 
 */
[^();+\-*/:=<>,$! \t\n\r\x00-\x1F\x7F]+  { 
                                           if (yyleng > NAMELENG)
                                           {
                                               errmsg(err_name_len, yytext, NAMELENG);
                                               return ERROR; //trigger yyerror
                                           }
                                           else
                                           {
                                               if (yylval.nameIndex = install(yytext)) // install, obtain index
                                                   return NAME;
                                               else
                                                   return ERROR; //trigger yyerror
                                           }
                                         }

":="    { return ASSIGN; }

.       { return yytext[0]; }

 /*
   Handle EOF as follows:
    - An input of ctrl-D from stdin triggers EOF and exits.
    - EOF from a file:
        close file, display number of lines processed
        if interactive mode (e.g. user issued a load command)
            prompt for next input
        else batch mode (e.g. input file was redirected to the program)
            return 0 to exit
 */
<<EOF>> { 
          if (yyin == stdin)
          {
              clearerr(yyin); // prevent infinite loop when ctrl-D is input
              return 0;
          }
          else // delete buffer, close file, restart stdin
          {
              readfile = false;
              echo = false;
              yy_delete_buffer(YY_CURRENT_BUFFER); // reclaim buffer space 
              fclose(yyin);
              printf("   %d lines processed from %s\n", lineNo, filename);

              if (interactive)
              {
                  yyrestart(stdin);
                  printf(PROMPT);
              }
              else
                  return 0; // batch mode only processes the redirected file then quits
          }  
        }

%%

void yyerror(const char *msg)
{
    printf("\nyyerror:  Line %d: %s at '%s'\n", lineNo, msg, yytext);
    setError(true, "yyerror");   // flag the error
}

