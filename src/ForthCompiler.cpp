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

const int IMMEDIATE   = PRECEDENCE_IMMEDIATE;
const int NONDEFERRED = PRECEDENCE_NON_DEFERRED;

#include "ForthWords.h"

size_t NUMBER_OF_INTRINSIC_WORDS =
   sizeof(ForthWords) / sizeof(ForthWords[0]);

extern int debug;

// Provided by ForthVM.cpp

extern vector<DictionaryEntry> Dictionary;
extern vector<char*> StringTable;
void ClearControlStacks();
void OpsCopyInt (int, int);
void OpsPushInt (int);
void OpsPushTwoInt (int, int);
void OpsPushDouble (double);
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

// Provided by vm32.asm
extern "C" int* GlobalSp;
extern "C" int* GlobalRp;
extern "C" byte* GlobalTp;
extern "C" int JumpTable[];
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

const char* C_ErrorMessages[] =
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

