// ForthCompiler.h
//
// Copyright (c) 1998--2003 Krishna Myneni, Creative Consulting for
//   Research and Education
//
// This software is provided under the terms of the GNU General Public License.
//
// Last Revised: 2003-04-15

#ifndef __FORTHCOMPILER_H__
#define __FORTHCOMPILER_H__

#define byte unsigned char
#define NUMBER_OF_INTRINSIC_WORDS 252
#define NUMBER_OF_NON_DEFERRED_WORDS 20
#define NUMBER_OF_IMMEDIATE_WORDS 28
#define PRECEDENCE_NONE         0
#define PRECEDENCE_IMMEDIATE    1
#define PRECEDENCE_NON_DEFERRED 2
#define EXECUTE_NONE            0
#define EXECUTE_UP_TO           1
#define EXECUTE_CURRENT_ONLY    2
#define TRUE -1
#define FALSE 0
#define MAX_ERR_MESSAGES 13

// Error codes; The corresponding error messages are given in
//   the const char* array C_ErrorMessages, in ForthCompiler.cpp

#define E_C_NOERROR         0
#define E_C_ENDOFSTREAM     1
#define E_C_ENDOFDEF        2
#define E_C_ENDOFSTRING     3
#define E_C_NOTINDEF        4
#define E_C_OPENFILE        5
#define E_C_INCOMPLETEIF    6
#define E_C_INCOMPLETEBEGIN 7
#define E_C_UNKNOWNWORD     8
#define E_C_NODO            9
#define E_C_INCOMPLETELOOP  10
#define E_C_INCOMPLETECASE  11
#define E_C_VMERROR         12

struct DictionaryEntry
{
  char WordName[32];
  byte Precedence;
  byte WordCode;
  void* Cfa;
  void* Pfa;
};


char* ExtractName (char*, char*);
int IsForthWord (char*, DictionaryEntry*);
int IsFloat (char*, float*);
int IsInt (char*, int*);
int ForthCompiler (vector<byte>*, int*);
void OutputForthByteCode (vector<byte>*);
void SetForthInputStream (istream&);
void SetForthOutputStream (ostream&);

#endif
