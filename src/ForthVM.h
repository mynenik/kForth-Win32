// ForthVM.h
//
// Copyright (c) 1996--2020 Krishna Myneni
// 
// Provided under the terms of the GNU Affero General Public License
// (AGPL) v 3.0 or later.

#ifndef __FORTHVM_H__
#define __FORTHVM_H__

#define MAX_V_ERR_MESSAGES 22

// Virtual machine error codes

#define E_V_NOERROR         0
#define E_V_NOTADDR         1
#define E_V_NOTVAL          2
#define E_V_BADTYPE         3
#define E_V_DIV_ZERO        4
#define E_V_RET_STK_CORRUPT 5
#define E_V_BADCODE         6
#define E_V_STK_UNDERFLOW   7
#define E_V_QUIT            8
#define E_V_REALLOT         9
#define E_V_CREATE         10
#define E_V_NO_EOS         11
#define E_V_NO_DO          12
#define E_V_NO_BEGIN       13
#define E_V_ELSE_NO_IF     14
#define E_V_THEN_NO_IF     15
#define E_V_ENDOF_NO_OF    16
#define E_V_NO_CASE        17
#define E_V_OPENFILE       18
#define E_V_BADSTACKADDR   19
#define E_V_DIV_OVERFLOW   20
#define E_V_DBL_OVERFLOW   21

#define DEFAULT_OUTPUT_FILENAME "kforth.out"

int OpenForth ();
void CloseForth ();
void RemoveLastWord ();
vector<DictionaryEntry>::iterator LocateWord (char*);
void ClearControlStacks ();
void OpsCopyInt (int, int);
void OpsPushInt (int);
void PrintVM_Error (int);
int ForthVM (vector<byte>*, int**, byte**);

// The following C++ functions have C linkage

extern "C" {
int CPP_colon();
int CPP_semicolon();
int CPP_backslash();
int CPP_lparen();
int CPP_dotparen();
int CPP_tick();
int CPP_find();
int CPP_dot();
int CPP_dotr();
int CPP_udot0();
int CPP_udot();
int CPP_udotr();
int CPP_ddot();
int CPP_fdot();
int CPP_dots();
int CPP_emit();
int CPP_cr();
int CPP_spaces();
int CPP_type();
int CPP_allot();
int CPP_queryallot();
int CPP_words();
int CPP_word();
int CPP_create();
int CPP_variable();
int CPP_fvariable();
int CPP_constant();
int CPP_fconstant();
int CPP_char();
int CPP_bracketchar();
int CPP_brackettick();
int CPP_literal();
int CPP_cquote();
int CPP_squote();
int CPP_dotquote();
int CPP_forget();
int CPP_tofile();
int CPP_console();
int CPP_do();
int CPP_querydo();
int CPP_leave();
int CPP_abortquote();
int CPP_begin();
int CPP_while();
int CPP_repeat();
int CPP_until();
int CPP_again();
int CPP_if();
int CPP_else();
int CPP_then();
int CPP_case();
int CPP_endcase();
int CPP_of();
int CPP_endof();
int CPP_recurse();
int CPP_does();
int CPP_immediate();
int CPP_nondeferred();
int CPP_evaluate();
int CPP_source();
int CPP_refill();
int CPP_spstore();
int CPP_rpstore();
}
#endif

