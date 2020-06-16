// ForthCompiler.cpp
//
// FORTH compiler to generate FORTH Byte Code (FBC) from expressions
//   or programs
//
// Copyright (c) 1998--2020 Krishna Myneni and David P. Wallace,
//
// This software is provided under the terms of the GNU Affero
// General Public License (AGPL) v 3.0 or later.
//

#include <iostream>
#include <fstream>
#include <string.h>
#include <ctype.h>
#include <stdlib.h>
#include "fbc.h"
#include <vector>
#include <stack>
using namespace std;
#include "ForthCompiler.h"

extern int debug;

// Provided by ForthVM.cpp

extern vector<DictionaryEntry> Dictionary;
extern vector<char*> StringTable;
void ClearControlStacks();
void OpsPushInt (int);
void PrintVM_Error (int);
int ForthVM (vector<byte>*, int**, byte**);
vector<DictionaryEntry>::iterator LocateWord (char*);
void RemoveLastWord();

extern "C" {

  // Provided by ForthVM.cpp

  int CPP_then();
  int CPP_immediate();
  int CPP_nondeferred();
  int CPP_source();
  int CPP_refill();

  // Provided by vm.s, vmc.c

  int C_numberquery();
  int L_abort();
}


extern "C" int* GlobalSp;
extern "C" int* GlobalRp;
extern "C" byte* GlobalTp;
extern "C" int* JumpTable;
extern "C" int Base;
extern "C" int State;  // TRUE = compile, FALSE = interpret
extern "C" char* pTIB;
extern "C"  char TIB[];  // contains current line of input

// stacks for keeping track of nested control structures

vector<int> ifstack;	// stack for if-then constructs
vector<int> beginstack;	// stack for begin ... constructs
vector<int> whilestack;	// stack for while jump holders
vector<int> dostack;    // stack for do loops
vector<int> querydostack; // stack for conditional do loops
vector<int> leavestack; // stack for leave jumps
vector<int> recursestack; // stack for recursion
vector<int> casestack;  // stack for case jumps
vector<int> ofstack;   // stack for of...endof constructs

int linecount;

// The global input and output streams

istream* pInStream ;
ostream* pOutStream ;

// Global ptr to current opcode vector

vector<byte>* pCurrentOps;

// The word currently being compiled (needs to be global)

DictionaryEntry NewWord;

char* WordNames[] =
    {
        "WORD", "WORDS", "FIND",
	"'", "[']", "[", "]",
	"CREATE", "DOES>", ">BODY",
	"FORGET", "COLD",
	"ALLOT", "?ALLOT",
	"LITERAL", "EVALUATE", "IMMEDIATE",
	"CONSTANT", "FCONSTANT",
	"VARIABLE", "FVARIABLE",
	"CELLS", "CELL+", "CHAR+",
	"DFLOATS", "DFLOAT+", "SFLOATS", "SFLOAT+",
	"?", "@", "!",
	"2@", "2!", "A@",
        "C@", "C!",
        "W@", "W!",
        "F@", "F!",
        "DF@", "DF!",
        "SF@", "SF!",
	"SP@", "SP!",
	"RP@", "RP!",
        ">R", "R>", "R@",
	"2>R", "2R>", "2R@",
        "?DUP",
        "DUP", "DROP", "SWAP",
        "OVER", "ROT", "-ROT",
	"NIP", "TUCK", "PICK", "ROLL",
        "2DUP", "2DROP", "2SWAP",
        "2OVER", "2ROT",
        "DEPTH",
	"BASE", "BINARY", "DECIMAL", "HEX",
        "1+", "1-", "2+", "2-",
	"2*", "2/",
        "DO", "?DO",
	"LOOP", "+LOOP",
	"LEAVE", "UNLOOP",
	"I", "J",
	"BEGIN", "WHILE", "REPEAT",
	"UNTIL", "AGAIN",
	"IF", "ELSE", "THEN",
	"CASE", "ENDCASE", "OF", "ENDOF",
	"RECURSE", "BYE",
        "EXIT", "QUIT", "ABORT",
	"ABORT\x22", "USLEEP",
        "EXECUTE", "CALL", "SYSTEM",
	"TIME&DATE", "MS", "MS@",
	"CHDIR", ">FILE", "CONSOLE",
	"\\", "(", ".(",
	"\x22", "C\x22", "S\x22",
	"COUNT", "NUMBER?",
	"<#", "#", "#S",
	"#>", "SIGN", "HOLD",
        ".", ".R",
	"D.",
	"U.", "U.R",
	"F.", ".\x22", ".S",
        "CR", "SPACES", "EMIT", "TYPE",
	"BL", "[CHAR]", "CHAR",
	"KEY", "KEY?", "ACCEPT",
        "SEARCH", "COMPARE",
        "=", "<>", "<", ">", "<=", ">=",
	"U<", "U>",
	"0<", "0=", "0<>", "0>",
	"D<", "D=", "DU<", "D0=",
	"FALSE", "TRUE",
        "AND", "OR", "XOR", "NOT", "INVERT",
	"LSHIFT", "RSHIFT",
        "+", "-", "*", "/",
	"MOD", "/MOD",
	"*/", "*/MOD", "+!",
	"D+", "D-",
	"M+", "M*", "M/",
	"M*/",
	"UM*", "UM/MOD",
	"FM/MOD", "SM/REM",
        "ABS", "NEGATE", "MIN", "MAX",
	"DABS", "DNEGATE",
	"OPEN", "LSEEK", "CLOSE",
	"READ", "WRITE", "IOCTL",
	"FILL", "ERASE",
	"CMOVE", "CMOVE>",
        "FDUP", "FDROP", "FSWAP",
        "FOVER", "FROT",
        "F=", "F<>", "F<", "F>", "F<=", "F>=",
	"F0=", "F0<",
        "F+", "F-", "F*", "F/", "F**", "FSQRT",
        "FABS", "FNEGATE",
	"FLOOR", "FROUND", "FTRUNC",
	"FMIN", "FMAX",
        "FSIN", "FCOS", "FTAN",
        "FACOS", "FASIN", "FATAN",
	"FATAN2",
        "FLOG", "FLN", "FEXP",
        "DEG>RAD", "RAD>DEG",
        "S>D", "S>F", "D>F", "F>D",
	"FROUND>S", "FTRUNC>S"
    };

byte WordCodes[] =
    {
        OP_WORD, OP_WORDS, OP_FIND,
	OP_TICK, OP_BRACKETTICK, OP_LBRACKET, OP_RBRACKET,
	OP_CREATE, OP_DOES, OP_TOBODY,
	OP_FORGET, OP_COLD,
	OP_ALLOT, OP_QUERYALLOT,
	OP_LITERAL, OP_EVALUATE, OP_IMMEDIATE,
	OP_CONSTANT, OP_FCONSTANT,
	OP_VARIABLE, OP_FVARIABLE,
	OP_CELLS, OP_CELLPLUS, OP_INC,
	OP_DFLOATS, OP_DFLOATPLUS, OP_CELLS, OP_CELLPLUS,
	OP_QUESTION, OP_FETCH, OP_STORE,
	OP_DFFETCH, OP_DFSTORE, OP_AFETCH,
        OP_CFETCH, OP_CSTORE,
        OP_WFETCH, OP_WSTORE,
        OP_DFFETCH, OP_DFSTORE,
        OP_DFFETCH, OP_DFSTORE,
        OP_SFFETCH, OP_SFSTORE,
	OP_SPFETCH, OP_SPSTORE,
	OP_RPFETCH, OP_RPSTORE,
        OP_PUSH, OP_POP, OP_RFETCH,
        OP_TWOPUSH, OP_TWOPOP, OP_TWORFETCH,
        OP_QUERYDUP,
        OP_DUP, OP_DROP, OP_SWAP,
        OP_OVER, OP_ROT, OP_MINUSROT,
	OP_NIP, OP_TUCK, OP_PICK, OP_ROLL,
        OP_2DUP, OP_2DROP, OP_2SWAP,
        OP_2OVER, OP_2ROT,
        OP_DEPTH,
	OP_BASE, OP_BINARY, OP_DECIMAL, OP_HEX,
        OP_INC, OP_DEC, OP_TWOPLUS, OP_TWOMINUS,
	OP_TWOSTAR, OP_TWODIV,
        OP_DO, OP_QUERYDO,
	OP_LOOP, OP_PLUSLOOP,
	OP_LEAVE, OP_UNLOOP,
	OP_I, OP_J,
	OP_BEGIN, OP_WHILE, OP_REPEAT,
	OP_UNTIL, OP_AGAIN,
	OP_IF, OP_ELSE, OP_THEN,
	OP_CASE, OP_ENDCASE, OP_OF, OP_ENDOF,
	OP_RECURSE, OP_BYE,
        OP_RET, OP_QUIT, OP_ABORT,
	OP_ABORTQUOTE, OP_USLEEP,
        OP_EXECUTE, OP_CALL, OP_SYSTEM,
	OP_TIMEANDDATE, OP_MS, OP_MSFETCH,
	OP_CHDIR, OP_TOFILE, OP_CONSOLE,
	OP_BACKSLASH, OP_LPAREN, OP_DOTPAREN,
	OP_CQUOTE, OP_CQUOTE, OP_SQUOTE,
	OP_COUNT, OP_NUMBERQUERY,
	OP_BRACKETSHARP, OP_SHARP, OP_SHARPS,
	OP_SHARPBRACKET, OP_SIGN, OP_HOLD,
        OP_DOT, OP_DOTR,
	OP_DDOT,
	OP_UDOT, OP_UDOTR,
	OP_FDOT, OP_DOTQUOTE, OP_DOTS,
        OP_CR, OP_SPACES, OP_EMIT, OP_TYPE,
	OP_BL, OP_BRACKETCHAR, OP_CHAR,
	OP_KEY, OP_KEYQUERY, OP_ACCEPT,
        OP_SEARCH, OP_COMPARE,
        OP_EQ, OP_NE, OP_LT, OP_GT, OP_LE, OP_GE,
	OP_ULT, OP_UGT,
	OP_ZEROLT, OP_ZEROEQ, OP_ZERONE, OP_ZEROGT,
	OP_DLT, OP_DEQ, OP_DULT, OP_DZEROEQ,
	OP_FALSE, OP_TRUE,
        OP_AND, OP_OR, OP_XOR, OP_NOT, OP_NOT,
	OP_LSHIFT, OP_RSHIFT,
        OP_ADD, OP_SUB, OP_MUL, OP_DIV,
	OP_MOD, OP_SLASHMOD,
	OP_STARSLASH, OP_STARSLASHMOD, OP_PLUSSTORE,
	OP_DPLUS, OP_DMINUS,
	OP_MPLUS, OP_MSTAR, OP_MSLASH,
	OP_MSTARSLASH,
	OP_UMSTAR, OP_UMSLASHMOD,
	OP_FMSLASHMOD, OP_SMSLASHREM,
        OP_ABS, OP_NEG, OP_MIN, OP_MAX,
	OP_DABS, OP_DNEGATE,
	OP_OPEN, OP_LSEEK, OP_CLOSE,
	OP_READ, OP_WRITE, OP_IOCTL,
	OP_FILL, OP_ERASE,
	OP_CMOVE, OP_CMOVEFROM,
        OP_2DUP, OP_2DROP, OP_2SWAP,
        OP_2OVER, OP_2ROT,
        OP_FEQ, OP_FNE, OP_FLT, OP_FGT, OP_FLE, OP_FGE,
	OP_FZEROEQ, OP_FZEROLT,
        OP_FADD, OP_FSUB, OP_FMUL, OP_FDIV, OP_FPOW, OP_FSQRT,
        OP_FABS, OP_FNEG,
	OP_FLOOR, OP_FROUND, OP_FTRUNC,
	OP_FMIN, OP_FMAX,
        OP_FSIN, OP_FCOS, OP_FTAN,
        OP_FACOS, OP_FASIN, OP_FATAN,
	OP_FATAN2,
        OP_FLOG, OP_FLN, OP_FEXP,
        OP_DEGTORAD, OP_RADTODEG,
        OP_STOD, OP_STOF, OP_DTOF, OP_FTOD,
	OP_FROUNDTOS, OP_FTRUNCTOS
    };

// Non-deferred words are executed immediately by
//   the interpreter in the non-compiling state.

byte NondeferredWords[] =
{
  OP_BACKSLASH,
  OP_DOTPAREN,
  OP_BINARY,
  OP_DECIMAL,
  OP_HEX,
  OP_WORD,
  OP_TICK,
  OP_CREATE,
  OP_FORGET,
  OP_COLD,
  OP_ALLOT,
  OP_QUERYALLOT,
  OP_CONSTANT,
  OP_FCONSTANT,
  OP_VARIABLE,
  OP_FVARIABLE,
  OP_CHAR,
  OP_TOFILE,
  OP_CONSOLE,
};

byte ImmediateWords[] =
{
  OP_BACKSLASH,
  OP_LPAREN,
  OP_DOTPAREN,
  OP_BRACKETCHAR,
  OP_BRACKETTICK,
  OP_LBRACKET,
  OP_RBRACKET,
  OP_LITERAL,
  OP_CQUOTE,
  OP_SQUOTE,
  OP_DOTQUOTE,
  OP_DO,
  OP_QUERYDO,
  OP_LEAVE,
  OP_ABORTQUOTE,
  OP_BEGIN,
  OP_WHILE,
  OP_REPEAT,
  OP_UNTIL,
  OP_AGAIN,
  OP_IF,
  OP_ELSE,
  OP_THEN,
  OP_CASE,
  OP_ENDCASE,
  OP_OF,
  OP_ENDOF,
  OP_RECURSE
};


char* C_ErrorMessages[] =
{
	"",
	"",
	"End of definition with no beginning",
	"End of string",
        "Not allowed inside colon definition",
	"Error opening file",
	"Incomplete IF...THEN structure",
	"Incomplete BEGIN structure",
	"Unknown word",
	"No matching DO",
	"Incomplete DO loop",
	"Incomplete CASE structure",
	"VM returned error"
};


//---------------------------------------------------------------

int IsForthWord (char* name, DictionaryEntry* pE)
{
// Locate and Return a copy of the dictionary entry
//   with the specified name.  Return True if found,
//   False otherwise. A copy of the entry is returned
//   in *pE.

    vector<DictionaryEntry>::iterator i = LocateWord (name);

    if (i != (vector<DictionaryEntry>::iterator) NULL)
    {
        *pE = *i;
        return TRUE;
    }
    else
        return FALSE;
}
//---------------------------------------------------------------

void OutputForthByteCode (vector<byte>* pFBC)
{
// Output opcode vector to an output stream for use in
//   debugging the compiler.

    int i, n = pFBC->size();
    byte* bp = (byte*) &(*pFBC)[0]; // ->begin();

    *pOutStream << "\nOpcodes:\n";
    for (i = 0; i < n; i++)
    {
        *pOutStream << ((int) *bp) << ' ';
        if (((i + 1) % 8) == 0) *pOutStream << '\n';
        ++bp;
    }
    *pOutStream << '\n';
    return;
}
//---------------------------------------------------------------

void SetForthInputStream (istream& SourceStream)
{
  // Set the input stream for the Forth Compiler and Virtual Machine

  pInStream = &SourceStream;
}
//--------------------------------------------------------------

void SetForthOutputStream (ostream& OutStream)
{
  // Set the output stream for the Forth Compiler and Virtual Machine

  pOutStream = &OutStream;
}
//---------------------------------------------------------------

int ForthCompiler (vector<byte>* pOpCodes, int* pLc)
{
// The FORTH Compiler
//
// Reads and compile the source statements from the input stream
//   into a vector of FORTH Byte Codes.
//
// Return value:
//
//  0   no error
//  other --- see ForthCompiler.h

  int ecode = 0, opcount = 0;
  char s[256], WordToken[256], filename[256];
  char *begin_string, *end_string, *str;
  double fval;
  int i, j, ival, *sp;
  vector<byte>::iterator ib1, ib2;
  vector<int>::iterator iI;
  DictionaryEntry d;
  vector<DictionaryEntry>::iterator id;
  byte opval, *fp, *ip, *bp, *tp;

  static bool postpone = FALSE;

  if (debug) cout << ">Compiler Sp: " << GlobalSp << " Rp: " << GlobalRp << endl;

  fp = (byte *) &fval;
  ip = (byte *) &ival;

  // if (! State) linecount = 0;
  linecount = *pLc;
  pCurrentOps = pOpCodes;

  while (TRUE)
    {
      // Read each line and parse

      pInStream->getline(TIB, 255);
      if (debug) (*pOutStream) << TIB << endl;

      if (pInStream->fail())
	{
	  if (State)
	    {
	      ecode = E_C_ENDOFSTREAM;  // reached end of stream before end of definition
	      break;
	    }
	  // pOpCodes->push_back(OP_RET);
	  break;    // end of stream reached
	}
      ++linecount;
      pTIB = TIB;
      while (*pTIB && (pTIB < (TIB + 255)))
	{
	  if (*pTIB == ' ' || *pTIB == '\t')
	    ++pTIB;

	  else if ((*pTIB == ':') && (*(pTIB+1) == ' '))
	    {
	      if (pOpCodes->size())
		{
		  // Execute the code outside of a definition

		  pOpCodes->push_back(OP_RET);
		  ival = ForthVM (pOpCodes, &sp, &tp);
		  pOpCodes->erase(pOpCodes->begin(), pOpCodes->end());
		  if (ival)
		    {
		      PrintVM_Error(ival);
		      ecode = E_C_VMERROR;
		      goto endcompile;
		    }
		}

	      State = TRUE;
	      ++pTIB;
	      pTIB = ExtractName (pTIB, WordToken);
	      strupr(WordToken);
	      strcpy (NewWord.WordName, WordToken);
	      NewWord.WordCode = OP_DEFINITION;
	      NewWord.Precedence = PRECEDENCE_NONE;
	      NewWord.Pfa = NULL;
	      NewWord.Cfa = NULL;

	      recursestack.erase(recursestack.begin(), recursestack.end());
	    }
	  else if (*pTIB == ';')
	    {
	      pOpCodes->push_back(OP_RET);

	      if (State)
		{
		  // Check for incomplete control structures

		  if (ifstack.size())
		    {
		      ecode = E_C_INCOMPLETEIF;
		      goto endcompile;
		    }
		  if (beginstack.size() || whilestack.size())
		    {
		      ecode = E_C_INCOMPLETEBEGIN;
		      goto endcompile;
		    }
		  if (dostack.size() || leavestack.size())
		    {
		      ecode = E_C_INCOMPLETELOOP;
		      goto endcompile;
		    }
		  if (casestack.size() || ofstack.size())
		    {
		      ecode = E_C_INCOMPLETECASE;
		      goto endcompile;
		    }

		  // Add a new entry into the dictionary

		  if (debug) OutputForthByteCode (pOpCodes);

		  NewWord.Pfa = new byte[pOpCodes->size()];
		  NewWord.Cfa = NewWord.Pfa;

		  // Resolve any self references (recursion)

		  bp = (byte*) &NewWord.Pfa;
		  while (recursestack.size())
		    {
		      i = recursestack[recursestack.size() - 1];
		      ib1 = pOpCodes->begin() + i;
		      for (i = 0; i < sizeof(void*); i++) *ib1++ = *(bp + i);
		      recursestack.pop_back();
		    }

		  byte* dest = (byte*) NewWord.Pfa;
		  bp = (byte*) &(*pOpCodes)[0]; // ->begin();
		  while ((vector<byte>::iterator) bp < pOpCodes->end()) *dest++ = *bp++;
		  if (IsForthWord(NewWord.WordName, &d))
		    *pOutStream << NewWord.WordName << " is redefined\n";
		  Dictionary.push_back(NewWord);
		  pOpCodes->erase(pOpCodes->begin(), pOpCodes->end());
		  State = FALSE;
		}
	      else
		{
		  ecode = E_C_ENDOFDEF;
		  goto endcompile;
		}
	      ++pTIB;
	    }
	  else
	    {
	      pTIB = ExtractName (pTIB, WordToken);
	      strupr(WordToken);

	      if (IsForthWord(WordToken, &d))
		{
		  pOpCodes->push_back(d.WordCode);


		  if (d.WordCode == OP_DEFINITION)
		    {
		      OpsPushInt((int) d.Cfa);
		    }
		  else if (d.WordCode == OP_ADDR)
		    {
		      // push address into the byte code vector

		      OpsPushInt((int) d.Pfa);
		    }
		  else if (d.WordCode == OP_IVAL)
		    {
		      // push value into the byte code vector

		      OpsPushInt(*((int*)d.Pfa));
		    }
		  else if (d.WordCode == OP_FVAL)
		    {
		      // push float value into the vector

		      bp = (byte*) d.Pfa;
		      for (i = 0; i < sizeof(double); i++)
			pOpCodes->push_back(*(bp + i));
		    }
		  else if (d.WordCode == OP_UNLOOP)
		    {
		      if (dostack.empty())
			{
			  ecode = E_C_NODO;
			  goto endcompile;
			}
		    }
		  else if (d.WordCode == OP_LOOP || d.WordCode == OP_PLUSLOOP)
		    {
		      if (dostack.empty())
			{
			  ecode = E_C_NODO;
			  goto endcompile;
			}
		      i = dostack[dostack.size() - 1];
		      if (leavestack.size())
			{
			  do
			    {
			      j = leavestack[leavestack.size() - 1];
			      if (j > i)
				{
				  ival = pOpCodes->size() - j + 1;
				  ib1 = pOpCodes->begin() + j;
				  *ib1++ = *ip;       // write the relative jump count
				  *ib1++ = *(ip + 1);
				  *ib1++ = *(ip + 2);
				  *ib1 = *(ip + 3);
				  leavestack.pop_back();
				}
			    } while ((j > i) && (leavestack.size())) ;
			}
		      dostack.pop_back();
		      if (querydostack.size())
			{
			  j = querydostack[querydostack.size() - 1];
			  if (j >= i)
			    {
			      CPP_then();
			      querydostack.pop_back();
			    }
			}
		    }
		  else
		    {
		      ;
		    }

		  int execution_method = EXECUTE_NONE;

		  if (postpone)
		    {
		      if ((d.Precedence & PRECEDENCE_IMMEDIATE) == 0)
			{
			  id = LocateWord (WordToken);
			  i = (d.WordCode == OP_DEFINITION) ? 5 : 1;
			  ib1 = pOpCodes->end() - i;
			  pOpCodes->erase(ib1, pOpCodes->end());
			  i = strlen(id->WordName);;
			  str = new char[i + 1];
			  strcpy(str, id->WordName);
			  pOpCodes->push_back(OP_ADDR);
			  StringTable.push_back(str);
			  OpsPushInt((int) str);
			  pOpCodes->push_back(OP_IVAL);
			  OpsPushInt(i);
			  pOpCodes->push_back(OP_EVALUATE);
			}
		      postpone = FALSE;
		      if (State && (d.Precedence | PRECEDENCE_NON_DEFERRED))
			NewWord.Precedence |= PRECEDENCE_NON_DEFERRED;
		    }
		  else
		    {
		      switch (d.Precedence)
			{
			case PRECEDENCE_IMMEDIATE:
			  execution_method = EXECUTE_CURRENT_ONLY;
			  break;
			case PRECEDENCE_NON_DEFERRED:
			  if (State)
			    NewWord.Precedence |= PRECEDENCE_NON_DEFERRED ;
			  else
			    execution_method = EXECUTE_UP_TO;
			  break;
			case (PRECEDENCE_NON_DEFERRED + PRECEDENCE_IMMEDIATE):
			  execution_method = State ? EXECUTE_CURRENT_ONLY :
			    EXECUTE_UP_TO;
			  break;
			default:
			  ;
			}
		    }
		  vector<byte> SingleOp;

		  switch (execution_method)
		    {
		    case EXECUTE_UP_TO:
		      // Execute the opcode vector immediately up to and
		      //   including the current opcode

		      pOpCodes->push_back(OP_RET);
		      if (debug) OutputForthByteCode (pOpCodes);
		      ival = ForthVM (pOpCodes, &sp, &tp);
		      pOpCodes->erase(pOpCodes->begin(), pOpCodes->end());
		      if (ival)
			{
			  PrintVM_Error(ival); ecode = E_C_VMERROR;
			  goto endcompile;
			}
		      break;

		    case EXECUTE_CURRENT_ONLY:
		      i = (d.WordCode == OP_DEFINITION) ? 5 : 1;
		      ib1 = pOpCodes->end() - i;
		      for (j = 0; j < i; j++) SingleOp.push_back(*(ib1+j));
		      SingleOp.push_back(OP_RET);
		      pOpCodes->erase(ib1, pOpCodes->end());
		      ival = ForthVM (&SingleOp, &sp, &tp);
		      SingleOp.erase(SingleOp.begin(), SingleOp.end());
		      if (ival)
			{
			  PrintVM_Error(ival); ecode = E_C_VMERROR;
			  goto endcompile;
			}
		      pOpCodes = pCurrentOps; // may have been redirected
		      break;

		    default:
		      ;
		    }

		}  // end if (IsForthWord())

	      else if (IsInt(WordToken, &ival))
		{
		  pOpCodes->push_back(OP_IVAL);
		  OpsPushInt(ival);
		}
	      else if (IsFloat(WordToken, &fval))
		{
		  pOpCodes->push_back(OP_FVAL);
		  for (i = 0; i < sizeof(double); i++)
		    pOpCodes->push_back(*(fp + i)); // store in proper order
		}
	      else if (strcmp(WordToken, "STATE") == 0)
		{
		  pOpCodes->push_back(OP_ADDR);
		  OpsPushInt((int) &State);
		}
	      else if (strcmp(WordToken, "POSTPONE") == 0)
		{
		  postpone = TRUE;
		}
	      else if (strcmp(WordToken, "NONDEFERRED") == 0)
		{
		  CPP_nondeferred();
		}
	      else if (strcmp(WordToken, "SOURCE") == 0)
	        {
		    pOpCodes->push_back(OP_ADDR);
		    OpsPushInt((int) CPP_source);
		    pOpCodes->push_back(OP_CALL);
		}
	      else if (strcmp(WordToken, "REFILL") == 0)
	        {
		    pOpCodes->push_back(OP_ADDR);
		    OpsPushInt((int) CPP_refill);
		    pOpCodes->push_back(OP_CALL);
		}
	      else if (strcmp(WordToken, "INCLUDE") == 0)
		{
		  if (State)
		    {
		      ecode = E_C_NOTINDEF;
		      goto endcompile;
		    }
		  ++pTIB;
		  pTIB = ExtractName (pTIB, WordToken);
		  strcpy (s, pTIB);  // save remaining part of input line in TIB
		  if (!strchr(WordToken, '.')) strcat(WordToken, ".4th");
		  strcpy (filename, WordToken);
		  ifstream f(filename);
		  if (!f)
		  {
		      if (getenv("KFORTH_DIR"))
		      {
			char temp[256];
			strcpy(temp, getenv("KFORTH_DIR"));
			strcat(temp, "\\");
			strcat(temp, filename);
			strcpy(filename, temp);
			f.clear();   // Clear the previous error
			f.open(filename);
			if (f)
			  {
			    *pOutStream << endl << filename << endl;
			  }
		      }
		  }

		  if (f.fail())
		    {
		      *pOutStream << endl << filename << endl;
		      ecode = E_C_OPENFILE;
		      goto endcompile;
		    }
		  istream* pTempIn = pInStream;  // save input stream ptr
		  SetForthInputStream(f);  // set the new input stream
		  int oldlc = linecount; linecount = 0;
		  ecode = ForthCompiler (pOpCodes, &linecount);
		  f.close();
		  pInStream = pTempIn;  // restore the input stream
		  if (ecode)
		    {
		      *pOutStream << filename << "  " ;
		      goto endcompile;
		    }
		  linecount = oldlc;

		  // Execute the code immediately

		  ival = ForthVM (pOpCodes, &sp, &tp);
		  pOpCodes->erase(pOpCodes->begin(), pOpCodes->end());
		  if (ival)
		    {
		      PrintVM_Error(ival); ecode = E_C_VMERROR;
		      goto endcompile;
		    }
		  strcpy(TIB, s);  // restore TIB with remaining input line
		  pTIB = TIB;      // restore ptr
		}
	      else
		{
		  *pOutStream << endl << WordToken << endl;
		  ecode = E_C_UNKNOWNWORD;  // unknown keyword
		  goto endcompile;
		}
	    }
	} // end while (*pTIB ...)

      if ((State == 0) && pOpCodes->size())
	{
	  // Execute the current line in interpretation state
	  pOpCodes->push_back(OP_RET);
	  if (debug) OutputForthByteCode (pOpCodes);
	  ival = ForthVM (pOpCodes, &sp, &tp);
	  pOpCodes->erase(pOpCodes->begin(), pOpCodes->end());
	  if (ival)
	    {
	      PrintVM_Error(ival); ecode = E_C_VMERROR; goto endcompile;
	    }
	}

    } // end while (TRUE)

endcompile:

  if ((ecode != E_C_NOERROR) && (ecode != E_C_ENDOFSTREAM))
    {
      // A compiler error occurred; reset to interpreter mode and
      //   clear all flow control stacks.

      State = FALSE;
      ClearControlStacks();
    }
  if (debug)
    {
      *pOutStream << "Error: " << ecode << " State: " << State << endl;
      *pOutStream << "<Compiler Sp: " << GlobalSp << " Rp: " << GlobalRp << endl;
    }
  *pLc = linecount;
  return ecode;
}

