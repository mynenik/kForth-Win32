// ForthVM.cpp
//
// The FORTH Virtual Machine (FVM) to execute Forth byte code.
//
// Copyright (c) 1996--2020 Krishna Myneni
//
// This software is provided under the GNU Affero General Public
// License (AGPL) v 3.0 or later.
//
#include <string.h>
#include <stdlib.h>
#include <math.h>
#include <iostream>
#include <fstream>
#include <sstream>
#include <vector>
using namespace std;

#include "fbc.h"
#include "ForthCompiler.h"
#include "ForthVM.h"
#include "kfmacros.h"

#define STACK_SIZE 32768
#define RETURN_STACK_SIZE 4096

extern int debug;

// Provided by ForthCompiler.cpp

extern WordTemplate ForthWords[];
void SetForthInputStream (istream&);
void SetForthOutputStream (ostream&);
extern const char* C_ErrorMessages[];
extern int linecount;
extern istream* pInStream ;    // global input stream
extern ostream* pOutStream ;   // global output stream
extern vector<byte>* pCurrentOps;
extern vector<int> ifstack;
extern vector<int> beginstack;
extern vector<int> whilestack;
extern vector<int> dostack;
extern vector<int> querydostack;
extern vector<int> leavestack;
extern vector<int> recursestack;
extern vector<int> casestack;
extern vector<int> ofstack;
extern DictionaryEntry NewWord;
extern size_t NUMBER_OF_INTRINSIC_WORDS;

extern "C" {

  // functions provided by vmc.c

  void set_start_time(void);
  int C_bracketsharp(void);
  int C_sharps(void);
  int C_sharpbracket(void);
  int C_word(void);

  // vm functions provided by vm32.asm

  int L_initfpu();
  int L_depth();
  int L_abort();
  int L_ret();
  int L_dabs();
  int L_2dup();
  int L_2drop();
  int L_dminus();
  int L_mstarslash();
  int vm (byte*);     // the machine code virtual machine

  // global pointers exported to other modules

  int* GlobalSp;   // the global stack pointer
  byte* GlobalTp;     // the global type stack pointer
  byte* GlobalIp;     // the global instruction pointer
  int* GlobalRp;      // the global return stack pointer
  byte* GlobalRtp;    // the global return type stack pointer
  int* BottomOfStack;
  int* BottomOfReturnStack;
  byte* BottomOfTypeStack;
  byte* BottomOfReturnTypeStack;
  int* vmEntryRp;
  int Base;
  int State;
  char* pTIB;
  int NumberCount;
  char WordBuf[256];
  char TIB[256];
  char NumberBuf[256];
}
extern "C" int JumpTable[];

// The Dictionary

vector<DictionaryEntry> Dictionary;

// Tables

vector<char*> StringTable;

// stacks; these are global to this module

int ForthStack[STACK_SIZE];                  // the stack
byte ForthTypeStack[STACK_SIZE];             // the value type stack
int ForthReturnStack[RETURN_STACK_SIZE];     // the return stack
byte ForthReturnTypeStack[RETURN_STACK_SIZE];// the return value type stack

bool FileOutput = FALSE;
vector<byte>* pPreviousOps;    // copy of ptr to old opcode vector for [ and ]
vector<byte> tempOps;          // temporary opcode vector for [ and ]

const char* V_ErrorMessages[] =
{
	"",
	"Not data type ADDR",
	"Not data type IVAL",
	"Invalid data type",
	"Divide by zero",
	"Return stack corrupt",
	"Invalid opcode",
        "Stack underflow",
	"",
	"Allot failed --- cannot reassign pfa",
	"Cannot create word",
	"End of string not found",
	"No matching DO",
	"No matching BEGIN",
	"ELSE without matching IF",
	"THEN without matching IF",
	"ENDOF without matching OF",
	"ENDCASE without matching CASE",
	"Cannot open file",
	"Address outside of stack space",
	"Division overflow",
	"Unsigned double number overflow"
};


//---------------------------------------------------------------

int OpenForth ()
{
// Initialize the FORTH dictionary; return the size of
//   the dictionary.

    int i, wcode;
    DictionaryEntry d;

    set_start_time();

    for (i = 0; i < NUMBER_OF_INTRINSIC_WORDS; i++)
    {
        strcpy(d.WordName, ForthWords[i].WordName);
	wcode = ForthWords[i].WordCode;
        d.WordCode   = wcode;
	d.Precedence = ForthWords[i].Precedence;
        d.Pfa = new byte[8];
	d.Cfa = d.Pfa;
	byte* bp = (byte*) d.Pfa;
	if (wcode >> 8)
	{
		// bp[0] = OP_CALLADDR;
		// *((int*) (bp+1)) = (int) JumpTable[wcode]; 
		// bp[5] = OP_RET;
		bp[0] = OP_ABORT;
		bp[1] = OP_RET;
	}
	else
	{
		bp[0] = wcode;
		bp[1] = OP_RET;
	}
        Dictionary.push_back(d);
    }

    // Initialize the global stack pointers

    BottomOfStack = ForthStack + STACK_SIZE - 1;
    BottomOfReturnStack = ForthReturnStack + RETURN_STACK_SIZE - 1;
    BottomOfTypeStack = ForthTypeStack + STACK_SIZE - 1;
    BottomOfReturnTypeStack = ForthReturnTypeStack + RETURN_STACK_SIZE - 1;

    GlobalSp = BottomOfStack;
    GlobalTp = BottomOfTypeStack;
    GlobalRp = BottomOfReturnStack;
    GlobalRtp = BottomOfReturnTypeStack;

    vmEntryRp = BottomOfReturnStack;
    Base = 10;
    State = FALSE;
    L_initfpu();

    return Dictionary.size();
}
//---------------------------------------------------------------

void CloseForth ()
{
    // Clean up the compiled words

    while (Dictionary.size())
    {
        RemoveLastWord();
    }

    // Clean up the string table

    vector<char*>::iterator j = StringTable.begin();

    while (j < StringTable.end())
    {
        if (*j) delete [] *j;
        ++j;
    }
    StringTable.erase(StringTable.begin(), StringTable.end());
}

//---------------------------------------------------------------

void RemoveLastWord ()
{
// Remove the last dictionary entry

	vector<DictionaryEntry>::iterator i = Dictionary.end() - 1;
	delete [] (byte*) i->Pfa;	// free memory
	if (i->Pfa != i->Cfa) delete [] (byte*) i->Cfa;
	Dictionary.pop_back();
}
//---------------------------------------------------------------

vector<DictionaryEntry>::iterator LocateWord (char* name)
{
// Search the dictionary from end to beginning for an entry
//   with the specified name. Return the iterator to the word
//   or NULL if not found.

	vector<DictionaryEntry>::iterator i;

	for (i = Dictionary.end()-1; i >= Dictionary.begin(); i--)
	{
        	if (strcmp(name, i->WordName) == 0) break;
	}

	if (i >= Dictionary.begin())
        	return i;
	else
		return ((vector<DictionaryEntry>::iterator) NULL);
}
//---------------------------------------------------------------

void ClearControlStacks ()
{
  // Clear the flow control stacks

  if (debug) cout << "Clearing all flow control stacks" << endl;
  ifstack.erase(ifstack.begin(), ifstack.end());
  beginstack.erase(beginstack.begin(),beginstack.end());
  whilestack.erase(whilestack.begin(),whilestack.end());
  dostack.erase(dostack.begin(), dostack.end());
  querydostack.erase(querydostack.begin(), querydostack.end());
  leavestack.erase(leavestack.begin(), leavestack.end());
  ofstack.erase(ofstack.begin(), ofstack.end());
  casestack.erase(casestack.begin(), casestack.end());
}
//---------------------------------------------------------------

void OpsCopyInt (int offset, int i)
{
  // Copy integer into the current opcode vector at the specified offset

  vector<byte>::iterator ib = pCurrentOps->begin() + offset;
  byte* ip = (byte*) &i;
  *ib++ = *ip; *ib++ = *(ip + 1); *ib++ = *(ip + 2); *ib = *(ip + 3);

}
//---------------------------------------------------------------

void OpsPushInt (int i)
{
  // push an integer into the current opcode vector

  byte* ip = (byte*) &i;
  for (int j = 0; j < sizeof(int); j++) pCurrentOps->push_back(*(ip + j));
}
//---------------------------------------------------------------

void PrintVM_Error (int ec)
{
  int ei = ec & 0xFF;
  int imax = (ec >> 8) ? MAX_C_ERR_MESSAGES : MAX_V_ERR_MESSAGES;
  const char *pMsg;
  char elabel[12];
  
  if ((ei >= 0) && (ei < imax)) {
    pMsg = (ec >> 8) ? C_ErrorMessages[ei] : V_ErrorMessages[ei];
    if (ec >> 8) strcpy( elabel, "Compiler");
    else strcpy(elabel, "VM");
    *pOutStream << elabel << "Error(" << ei << "): " <<
      pMsg << endl;
  }
}
//---------------------------------------------------------------

int ForthVM (vector<byte>* pFBC, int** pStackPtr, byte** pTypePtr)
{
// The FORTH Virtual Machine
//
// Arguments:
//
//      pFBC        pointer to vector of Forth byte codes
//      pStackPtr   receives pointer to the top item on the stack at exit
//      pTypePtr    receives pointer to the top item on the type stack at exit
//
// Return value: error code (see ForthVM.h)
//
if (debug)  cout << ">ForthVM Sp: " << GlobalSp << " Rp: " << GlobalRp << endl;
  if (pFBC->size() == 0) return 0;  // null opcode vector

  // Initialize the instruction ptr and error code

  // byte *ip = (byte*) pFBC->begin();
  byte *ip = (byte *) &(*pFBC)[0];
  int ecode = 0;

  // Execute the virtual machine; return when error occurs or
  //   the return stack is exhausted.

  ecode = vm (ip);

  if (ecode)
    {
      if (debug) cout << "vm Error: " << ecode << "  Offending OpCode: " << ((int) *(GlobalIp-1)) << endl;
      ClearControlStacks();
      GlobalRp = BottomOfReturnStack;        // reset the return stack ptrs
      GlobalRtp = BottomOfReturnTypeStack;
    }
  else if (GlobalSp > BottomOfStack)
  {
      ecode = E_V_STK_UNDERFLOW;
  }
  else if (GlobalRp > BottomOfReturnStack)
  {
      ecode = E_V_RET_STK_CORRUPT;
  }
  else
      ;

  // On stack underflow, update the global stack pointers.

  if ((ecode == E_V_STK_UNDERFLOW) || (ecode == E_V_RET_STK_CORRUPT))
  {
      L_abort();
  }

  // Set up return information

  *pStackPtr = GlobalSp + 1;
  *pTypePtr = GlobalTp + 1;
if (debug)  cout << "<ForthVM Sp: " << GlobalSp << " Rp: " << GlobalRp <<
	      "  vmEntryRp: " << vmEntryRp << endl;
  return ecode;
}
//---------------------------------------------------------------

// Use C linkage for all of the VM functions

extern "C" {

int CPP_backslash()
{
  // stack: ( -- | advance pTIB to end of line )

  while (*pTIB) ++pTIB;
  return 0;
}
// --------------------------------------------------------------

int CPP_lparen()
{
  // stack: ( -- | advance pTIB past end of comment )

  while (TRUE)
    {
      while ((pTIB < (TIB + 255)) && (! (*pTIB == ')')) && *pTIB) ++pTIB;
      if (*pTIB == ')')
	{
	  ++pTIB;
	  break;
	}
      else
	{
	  pInStream->getline(TIB, 255);
	  if (pInStream->fail()) return E_V_NO_EOS;
	  ++linecount;
	  pTIB = TIB;
	}
    }

  return 0;
}
//---------------------------------------------------------------

int CPP_dotparen()
{
  // stack: ( -- | display comment and advance pTIB past end of comment )

  while (TRUE)
    {
      while ((pTIB < (TIB + 255)) && (! (*pTIB == ')')) && *pTIB)
	{
	  *pOutStream << *pTIB;
	  ++pTIB;
	}

      if (*pTIB == ')')
	{
	  pOutStream->flush();
	  ++pTIB;
	  break;
	}
      else
	{
	  *pOutStream << endl;
	  pInStream->getline(TIB, 255);
	  if (pInStream->fail()) return E_V_NO_EOS;
	  ++linecount;
	  pTIB = TIB;
	}
    }

  return 0;
}
//---------------------------------------------------------------

int CPP_dot ()
{
  // stack: ( n -- | print n in current base )

  ++GlobalSp; ++GlobalTp;
  if (GlobalSp > BottomOfStack)
    return E_V_STK_UNDERFLOW;
  else
    {
      int n = *GlobalSp;
      if (n < 0)
	{
	  *pOutStream << '-';
	  *GlobalSp = abs(n);
	}
      --GlobalSp; --GlobalTp;
      return CPP_udot();
    }
  return 0;
}
//--------------------------------------------------------------

int CPP_dotr ()
{
  // stack: ( n1 n2 -- | print n1 in field n2 wide )

  ++GlobalSp; ++GlobalTp;
  if (GlobalSp > BottomOfStack) return E_V_STK_UNDERFLOW;

  int i, n, ndig, nfield, nchar;
  unsigned int u, utemp, uscale;

  nfield = *GlobalSp++; ++GlobalTp;
  if (GlobalSp > BottomOfStack) return E_V_STK_UNDERFLOW;

  if (nfield <= 0) return 0;  // don't print anything if field with <= 0

  n = *GlobalSp;
  u = abs(n);
  ndig = 1;
  uscale = 1;
  utemp = u;

  while (utemp /= Base) {++ndig; uscale *= Base;}
  int ntot = (n < 0) ? ndig + 1 : ndig;

  if (ntot <= nfield)
    {
      for (i = 0; i < (nfield - ntot); i++) *pOutStream << ' ';
    }

  if (n < 0) *pOutStream << '-';
  *GlobalSp-- = u; --GlobalTp;
  i = CPP_udot0();
  pOutStream->flush();
  return i;
}
//---------------------------------------------------------------

int CPP_udotr ()
{
  // stack: ( u n -- | print unsigned in field width n )

  ++GlobalSp; ++GlobalTp;
  if (GlobalSp > BottomOfStack) return E_V_STK_UNDERFLOW;

  int i, ndig, nfield, nchar;
  unsigned int u, utemp, uscale;

  nfield = *GlobalSp++; ++GlobalTp;
  if (GlobalSp > BottomOfStack) return E_V_STK_UNDERFLOW;

  if (nfield <= 0) return 0;  // don't print anything if field with <= 0

  u = *GlobalSp;
  ndig = 1;
  uscale = 1;
  utemp = u;

  while (utemp /= Base) {++ndig; uscale *= Base;}

  if (ndig <= nfield)
    {
      for (i = 0; i < (nfield - ndig); i++) *pOutStream << ' ';
    }
  *GlobalSp-- = u; --GlobalTp;
  i = CPP_udot0();
  pOutStream->flush();
  return i;
}
//---------------------------------------------------------------

int CPP_udot0 ()
{
  // stack: ( u -- | print unsigned single in current base )

  ++GlobalSp; ++GlobalTp;
  if (GlobalSp > BottomOfStack) return E_V_STK_UNDERFLOW;

  int i, ndig, nchar;
  unsigned int u, utemp, uscale;

  u = *GlobalSp;
  ndig = 1;
  uscale = 1;
  utemp = u;

  while (utemp /= Base) {++ndig; uscale *= Base;}

  for (i = 0; i < ndig; i++)
    {
      utemp = u/uscale;
      nchar = (utemp < 10) ? (utemp + 48) : (utemp + 55);
      *pOutStream << (char) nchar;
      u -= utemp*uscale;
      uscale /= Base;
    }
  return 0;
}
//--------------------------------------------------------------

int CPP_udot ()
{
  // stack: ( u -- | print unsigned single in current base followed by space )

  int e = CPP_udot0();
  if (e)
    return e;
  else
    {
      *pOutStream << ' ';
      pOutStream->flush();
    }
  return 0;
}
//---------------------------------------------------------------

int CPP_uddot ()
{
  // stack: ( ud -- | print unsigned double in current base )

  if ((GlobalSp + 2) > BottomOfStack) return E_V_STK_UNDERFLOW;

  unsigned int u1;

  u1 = *(GlobalSp + 1);
  if (u1 == 0)
    {
      ++GlobalSp; ++GlobalTp;
      return CPP_udot();
    }
  else
    {
      C_bracketsharp();
      C_sharps();
      C_sharpbracket();
      CPP_type();
      *pOutStream << ' ';
      pOutStream->flush();
    }

  return 0;
}
//---------------------------------------------------------------

int CPP_ddot ()
{
  // stack: ( d -- | print signed double length number )

  if ((GlobalSp + 2) > BottomOfStack)
    return E_V_STK_UNDERFLOW;
  else
    {
      int n = *(GlobalSp+1);
      if (n < 0)
	{
	  *pOutStream << '-';
	  L_dabs();
	}
      return CPP_uddot();
    }
  return 0;
}
//---------------------------------------------------------------

int CPP_fdot ()
{
  // stack: ( f -- | print floating point number )

  ++GlobalSp; ++GlobalTp; ++GlobalSp; ++GlobalTp;
  if (GlobalSp > BottomOfStack)
    return E_V_STK_UNDERFLOW;
  else
    {
      --GlobalSp;
      *pOutStream << *((double*) GlobalSp) << ' ';
      ++GlobalSp;
      (*pOutStream).flush();
    }
  return 0;
}
//---------------------------------------------------------------

int CPP_dots ()
{
  if (GlobalSp > BottomOfStack) return E_V_STK_UNDERFLOW;

  L_depth();
  ++GlobalSp; ++GlobalTp;
  int depth = *GlobalSp;
  ++GlobalSp; ++GlobalTp;

  if (debug)
    {
      *pOutStream << "\nTop of Stack = " << ((int)ForthStack);
      *pOutStream << "\nBottom of Stack = " << ((int)BottomOfStack);
      *pOutStream << "\nStack ptr = " << ((int)GlobalSp);
      *pOutStream << "\nDepth = " << depth;
    }

  if (depth > 0)
    {
      int i;
      byte* bptr;

      for (i = 0; i < depth; i++)
        {
	  if (*(GlobalTp + i) == OP_ADDR)
            {
                bptr = *((byte**) (GlobalSp + i));
                *pOutStream << "\n\taddr\t" << ((int)bptr);
            }
            else
            {
                *pOutStream << "\n\t\t" << *(GlobalSp + i);
            }
        }
    }
  else
    {
        *pOutStream << "<empty>";
    }
  *pOutStream << '\n';
  --GlobalSp; --GlobalTp;
  return 0;
}
//---------------------------------------------------------------

int CPP_tick ()
{
    // stack: ( "name" -- xt )
    // Return error if "name" is not found in current search order

    char name[128];
    pTIB = ExtractName(pTIB, name);
    strupr(name);
    DictionaryEntry d;
    if ( IsForthWord(name, &d) )
    {
        PUSH_ADDR((long int) d.Cfa)
    }
    else
        return E_C_UNKNOWNWORD;

    return 0;
}

int CPP_find ()
{
  // stack: ( ^str -- ^str 0 | xt_addr 1 | xt_addr -1 )

  ++GlobalSp; ++GlobalTp;
  if (*GlobalTp != OP_ADDR)
    return E_V_NOTADDR;
  unsigned char* s = *((unsigned char**) GlobalSp);
  char name [128];
  int len = *s;
  strncpy (name, (char*) s+1, len);
  name[len] = 0;
  strupr(name);
  vector<DictionaryEntry>::iterator i = LocateWord (name);
  if (i != (vector<DictionaryEntry>::iterator) NULL)
    {
      *GlobalSp-- = (int) i->Cfa;
      *GlobalTp-- = OP_ADDR;
      *GlobalSp-- =  (i->Precedence & PRECEDENCE_IMMEDIATE) ? 1 : -1 ;
      *GlobalTp-- = OP_IVAL;
    }
  else
    {
      --GlobalSp; --GlobalTp;
      *GlobalSp-- = 0;
      *GlobalTp-- = OP_IVAL;
    }
  return 0;
}
//---------------------------------------------------------------

int CPP_emit ()
{
  // stack: ( n -- | display character with ascii code n )

  ++GlobalSp; ++GlobalTp;
  if (GlobalSp > BottomOfStack)
    return E_V_STK_UNDERFLOW;
  else
    {
      *pOutStream << (char)(*GlobalSp);
      (*pOutStream).flush();
    }
  return 0;
}
//---------------------------------------------------------------

int CPP_cr ()
{
  *pOutStream << '\n';
  return 0;
}
//---------------------------------------------------------------

int CPP_spaces ()
{
  ++GlobalSp; ++GlobalTp;
  if (GlobalSp > BottomOfStack)
    return E_V_STK_UNDERFLOW;
  else
    {
      int n = *GlobalSp;
      if (n > 0)
	for (int i = 0; i < n; i++) *pOutStream << ' ';
      (*pOutStream).flush();
    }
  return 0;
}
//---------------------------------------------------------------

int CPP_type ()
{
  ++GlobalSp; ++GlobalTp;
  if (GlobalSp > BottomOfStack)
    return E_V_STK_UNDERFLOW;
  else
    {
      int n = *GlobalSp++; ++GlobalTp;
      if (GlobalSp > BottomOfStack)
	return E_V_STK_UNDERFLOW;
      if (*GlobalTp != OP_ADDR)
	return E_V_NOTADDR;
      char* cp = *((char**) GlobalSp);
      for (int i = 0; i  < n; i++) *pOutStream << *cp++;
      (*pOutStream).flush();
    }
  return 0;
}
//---------------------------------------------------------------

int CPP_words ()
{
  char *cp, field[16];
  int nc;

  for (int i = 0; i < Dictionary.size(); i++)
    {
      memset (field, 32, 16);
      field[15] = '\0';
      cp = Dictionary[i].WordName;
      nc = strlen(cp);
      strncpy (field, cp, (nc > 15) ? 15 : nc);
      *pOutStream << field;
      if ((i+1) % 5 == 0) *pOutStream << '\n';
    }
  return 0;
}
//---------------------------------------------------------------

int CPP_allot ()
{
  ++GlobalSp; ++GlobalTp;
  if (GlobalSp > BottomOfStack)
    return E_V_STK_UNDERFLOW;
  if (*GlobalTp != OP_IVAL)
    return E_V_BADTYPE;  // need an int

  vector<DictionaryEntry>::iterator id = Dictionary.end() - 1;
  int n = *GlobalSp;
  if (n > 0)
    {
      if (id->Pfa == NULL)
	{
	  id->Pfa = new byte[n];
	  if (id->Pfa) memset (id->Pfa, 0, n);
	}
      else
	return E_V_REALLOT;
    }
  else
    id->Pfa = NULL;

  return 0;
}
//--------------------------------------------------------------

int CPP_queryallot ()
{
  // stack: ( n -- a | allot n bytes and leave starting address on the stack )

  int e = CPP_allot();
  if (!e)
    {
      // Get last word's Pfa and leave on the stack

      vector<DictionaryEntry>::iterator id = Dictionary.end() - 1;
      *GlobalSp-- = (int) id->Pfa;
      *GlobalTp-- = OP_ADDR;
    }
  return e;
}
//---------------------------------------------------------------

int CPP_word ()
{
  // stack: ( n -- ^str | parse next word in input stream )
  // n is the delimiting character and ^str is a counted string.
  DROP
  char delim = TOS;
  char *dp = WordBuf + 1;

  while (*pTIB)
    {
      if (*pTIB != delim) break;
      ++pTIB;
    }
  if (*pTIB)
    {
      int count = 0;
      while (*pTIB)
	{
	    // cout << '[' << *pTIB << ']';
	  if (*pTIB == delim) break;
	  *dp++ = *pTIB++;
	  ++count;
	}
      if (*pTIB) ++pTIB;  // consume the delimiter
      *WordBuf = count;
      *dp = ' ';
    }
  else
    {
      *WordBuf = 0;
    }
  *GlobalSp-- = (int) WordBuf;
  *GlobalTp-- = OP_ADDR;

  return 0;
}
//----------------------------------------------------------------

int CPP_create ()
{

  // stack: ( -- | create dictionary entry using next word in input stream )

  char token[128];
  pTIB = ExtractName(pTIB, token);
  int nc = strlen(token);

  if (nc)
    {
      DictionaryEntry NewWord;
      strupr(token);
      strcpy (NewWord.WordName, token);
      NewWord.WordCode = OP_ADDR;
      NewWord.Pfa = NULL;
      NewWord.Cfa = NULL;
      NewWord.Precedence = 0;

      Dictionary.push_back(NewWord);
      return 0;
    }
  else
    {
      return E_V_CREATE;  // create failed
    }
}
//-----------------------------------------------------------------

int CPP_variable ()
{
  // stack: ( -- | create dictionary entry and allot space )

  if (CPP_create()) return E_V_CREATE;
  *GlobalSp-- = sizeof(int);
  *GlobalTp-- = OP_IVAL;
  int e = CPP_allot();
  if (e) return e;
  vector<DictionaryEntry>::iterator id = Dictionary.end() - 1;
  byte *bp = new byte[6];
  id->Cfa = bp;
  bp[0] = OP_ADDR;
  *((int*) &bp[1]) = (int) id->Pfa;
  bp[5] = OP_RET;
  return 0;
}
//-----------------------------------------------------------------

int CPP_fvariable ()
{
  // stack: ( -- | create dictionary entry and allot space )

  if (CPP_create()) return E_V_CREATE;
  *GlobalSp-- = sizeof(double);
  *GlobalTp-- = OP_IVAL;
  int e = CPP_allot();
  if (e) return e;
  vector<DictionaryEntry>::iterator id = Dictionary.end() - 1;
  byte *bp = new byte[6];
  id->Cfa = bp;
  bp[0] = OP_ADDR;
  *((int*) &bp[1]) = (int) id->Pfa;
  bp[5] = OP_RET;
  return 0;
}
//------------------------------------------------------------------

int CPP_constant ()
{
  // stack: ( n -- | create dictionary entry and store n as constant )

  if (CPP_create()) return E_V_CREATE;
  vector<DictionaryEntry>::iterator id = Dictionary.end() - 1;
  id->WordCode = OP_IVAL;
  id->Pfa = new int[1];
  ++GlobalSp; ++GlobalTp;
  *((int*) (id->Pfa)) = *GlobalSp;
  byte *bp = new byte[7];
  id->Cfa = bp;
  bp[0] = OP_ADDR;
  *((int*) &bp[1]) = (int) id->Pfa;
  bp[5] = OP_FETCH;
  bp[6] = OP_RET;
  return 0;
}
//------------------------------------------------------------------

int CPP_fconstant ()
{
  // stack: ( f -- | create dictionary entry and store f )

  if (CPP_create()) return E_V_CREATE;
  vector<DictionaryEntry>::iterator id = Dictionary.end() - 1;
  id->WordCode = OP_FVAL;
  id->Pfa = new double[1];
  ++GlobalSp; ++GlobalTp;
  *((double*) (id->Pfa)) = *((double*)GlobalSp);
  ++GlobalSp; ++GlobalTp;
  byte *bp = new byte[7];
  id->Cfa = bp;
  bp[0] = OP_ADDR;
  *((int*) &bp[1]) = (int) id->Pfa;
  bp[5] = OP_DFFETCH;
  bp[6] = OP_RET;
  return 0;
}
//------------------------------------------------------------------

int CPP_char ()
{
  // stack: ( -- n | parse next word in input stream and return first char )

  *GlobalSp-- = 32;
  *GlobalTp-- = OP_IVAL;
  CPP_word();
  char* cp = *((char**) ++GlobalSp) + 1;
  *GlobalSp-- = *cp;
  *(GlobalTp + 1) = OP_IVAL ;
  return 0;
}
//-----------------------------------------------------------------

int CPP_bracketchar ()
{
  CPP_char();
  CPP_literal();
  return 0;
}
//------------------------------------------------------------------

int CPP_brackettick ()
{
  CPP_tick ();
  return CPP_literal();
}
//-------------------------------------------------------------------

int CPP_forget ()
{
  char token[128];

  pTIB = ExtractName (pTIB, token);
  strupr(token);

  vector<DictionaryEntry>::iterator id = LocateWord (token);
  if (id != (vector<DictionaryEntry>::iterator) NULL)
    {
      while (Dictionary.end() > id)
	RemoveLastWord();
    }
  else
    {
      *pOutStream << "No such word: " << token << '\n';
    }
  return 0;
}
//-------------------------------------------------------------------

int CPP_cold ()
{
  // stack: ( -- | restart the Forth environment )

  CloseForth();
  OpenForth();

  return 0;
}
//--------------------------------------------------------------------

int CPP_bye ()
{
  // stack: ( -- | close Forth and exit the process )

  CloseForth();
  *pOutStream << "Goodbye.\n";
  exit(0);

  return 0;
}
//--------------------------------------------------------------------

int CPP_tofile ()
{
  char filename[128];
  *filename = 0;

  pTIB = ExtractName (pTIB, filename);
  if (*filename == 0)
    {
      strcpy (filename, DEFAULT_OUTPUT_FILENAME);
      // cout << "Output redirected to " << filename << '\n';
    }
  ofstream *pFile = new ofstream (filename);
  if (! pFile->fail())
    {
      if (FileOutput)
	{
	  (*((ofstream*) pOutStream)).close();  // close current file output stream
	  delete pOutStream;
	}
      pOutStream = pFile;
      FileOutput = TRUE;
    }
  else
    {
      *pOutStream << "Failed to open output file stream.\n";
    }
  return 0;
}
//--------------------------------------------------------------------

int CPP_console ()
{
  if (FileOutput)
    {
      (*((ofstream*) pOutStream)).close();  // close the current file output stream
      delete pOutStream;
    }
  pOutStream = &cout;  // make console the new output stream
  FileOutput = FALSE;

  return 0;
}
//--------------------------------------------------------------------

int CPP_literal ()
{
  // stack: ( n -- | remove item from the stack and place in compiled opcodes )

  pCurrentOps->push_back(*(++GlobalTp));
  byte* bp = (byte*)(++GlobalSp);
  for (int i = 0; i < sizeof(int); i++) pCurrentOps->push_back(*bp++);
  return 0;
}
//-------------------------------------------------------------------

int CPP_cquote ()
{
  // compilation stack: ( -- | compile a counted string into the string table )
  // runtime stack: ( -- ^str | place address of counted string on stack )

  char* begin_string = pTIB ;
  char* end_string = strchr(begin_string, '"');
  if (end_string == NULL)
    {
      return E_V_NO_EOS;
    }
  pTIB = end_string + 1;
  int nc = (int) (end_string - begin_string);
  char* str = new char[nc + 2];
  *((byte*)str) = (byte) nc;
  strncpy(str+1, begin_string, nc);
  str[nc+1] = '\0';
  StringTable.push_back(str);
  pCurrentOps->push_back(OP_ADDR);
  OpsPushInt((long int) str);

  return 0;
}
//-------------------------------------------------------------------

int CPP_squote ()
{
  // compilation stack: ( -- | compile a string into the string table )
  // runtime stack: ( -- a count )

  int e = CPP_cquote();
  if (e) return e;
  char* s = *(StringTable.end() - 1);
  int v = s[0];
  pCurrentOps->push_back(OP_INC);
  pCurrentOps->push_back(OP_IVAL);
  OpsPushInt(v);

  return 0;
}
//-------------------------------------------------------------------

int CPP_dotquote ()
{
  // stack: ( -- | display a string delimited by quote from the input stream)

  int e = CPP_cquote();
  if (e) return e;

  pCurrentOps->push_back(OP_COUNT);
  pCurrentOps->push_back(OP_TYPE);

  return 0;
}
//------------------------------------------------------------------

int CPP_do ()
{
  // stack: ( -- | generate opcodes for beginning of loop structure )

  pCurrentOps->push_back(OP_PUSH);
  pCurrentOps->push_back(OP_PUSH);
  pCurrentOps->push_back(OP_PUSHIP);

  dostack.push_back(pCurrentOps->size());
  return 0;
}
//------------------------------------------------------------------

int CPP_querydo ()
{
  // stack: ( -- | generate opcodes for beginning of conditional loop )

  pCurrentOps->push_back(OP_2DUP);
  pCurrentOps->push_back(OP_EQ);
  CPP_if();
  pCurrentOps->push_back(OP_2DROP);
  CPP_else();
  CPP_do();

  querydostack.push_back(pCurrentOps->size());
  return 0;
}
//------------------------------------------------------------------

int CPP_leave ()
{
  // stack: ( -- | generate opcodes to jump out of the current loop )

  if (dostack.empty()) return E_V_NO_DO;
  pCurrentOps->push_back(OP_UNLOOP);
  pCurrentOps->push_back(OP_JMP);
  leavestack.push_back(pCurrentOps->size());
  OpsPushInt(0);
  return 0;
}
//------------------------------------------------------------------

int CPP_abortquote ()
{
  // stack: ( -- | generate opcodes to print message and abort )

  int nc = strlen(NewWord.WordName);;
  char* str = new char[nc + 3];
  strcpy(str, NewWord.WordName);
  strcat(str, ": ");
  StringTable.push_back(str);

  pCurrentOps->push_back(OP_JZ);
  OpsPushInt(25);   // relative jump count

// the relative jump count (above) must be modified if the
// instructions below are updated!

  pCurrentOps->push_back(OP_ADDR);
  OpsPushInt((int) str);
  pCurrentOps->push_back(OP_IVAL);
  OpsPushInt(nc+2);
  pCurrentOps->push_back(OP_TYPE);
  int e = CPP_dotquote();
  pCurrentOps->push_back(OP_CR);
  pCurrentOps->push_back(OP_ABORT);
  return e;

}
//------------------------------------------------------------------

int CPP_begin()
{
  // stack: ( -- | mark the start of a begin ... structure )

  beginstack.push_back(pCurrentOps->size());
  return 0;
}
//------------------------------------------------------------------

int CPP_while()
{
  // stack: ( -- | build the begin ... while ... repeat structure )

  if (beginstack.empty()) return E_V_NO_BEGIN;
  pCurrentOps->push_back(OP_JZ);
  whilestack.push_back(pCurrentOps->size());
  OpsPushInt(0);
  return 0;
}
//------------------------------------------------------------------

int CPP_repeat()
{
  // stack: ( -- | complete begin ... while ... repeat block )

  if (beginstack.empty()) return E_V_NO_BEGIN;  // no matching BEGIN

  int i = beginstack[beginstack.size()-1];
  beginstack.pop_back();

  int ival;

  if (whilestack.size())
    {
      int j = whilestack[whilestack.size()-1];
      if (j > i)
	{
	  whilestack.pop_back();
	  ival = pCurrentOps->size() - j + 6;
	  OpsCopyInt (j, ival);  // write the relative jump count
	}
    }

  ival = i - pCurrentOps->size();
  pCurrentOps->push_back(OP_JMP);
  OpsPushInt(ival);   // write the relative jump count

  return 0;
}
//-------------------------------------------------------------------

int CPP_until()
{
  // stack: ( -- | complete begin ... until block )

  if (beginstack.empty()) return E_V_NO_BEGIN;  // no matching BEGIN

  int i = beginstack[beginstack.size()-1];
  beginstack.pop_back();
  int ival = i - pCurrentOps->size();
  pCurrentOps->push_back(OP_JZ);
  OpsPushInt(ival);   // write the relative jump count

  return 0;
}
//-------------------------------------------------------------------

int CPP_again()
{
  // stack: ( -- | complete begin ... again block )

  if (beginstack.empty()) return E_V_NO_BEGIN;  // no matching BEGIN

  int i = beginstack[beginstack.size()-1];
  beginstack.pop_back();
  int ival = i - pCurrentOps->size();
  pCurrentOps->push_back(OP_JMP);
  OpsPushInt(ival);   // write the relative jump count

  return 0;
}
//--------------------------------------------------------------------

int CPP_if()
{
  // stack: ( -- | generate start of an if-then or if-else-then block )

  pCurrentOps->push_back(OP_JZ);
  ifstack.push_back(pCurrentOps->size());
  OpsPushInt(0);   // placeholder for jump count
  return 0;
}
//------------------------------------------------------------------

int CPP_else()
{
  // stack: ( -- | build the if-else-then block )

  pCurrentOps->push_back(OP_JMP);
  OpsPushInt(0);  // placeholder for jump count

  if (ifstack.empty()) return E_V_ELSE_NO_IF;  // ELSE without matching IF
  int i = ifstack[ifstack.size()-1];
  ifstack.pop_back();
  ifstack.push_back(pCurrentOps->size() - sizeof(int));
  int ival = pCurrentOps->size() - i + 1;
  OpsCopyInt (i, ival);  // write the relative jump count

  return 0;
}
//-------------------------------------------------------------------

int CPP_then()
{
  // stack: ( -- | complete the if-then or if-else-then block )

  if (ifstack.empty())
    return E_V_THEN_NO_IF;  // THEN without matching IF or IF-ELSE

  int i = ifstack[ifstack.size()-1];
  ifstack.pop_back();
  int ival = (int) (pCurrentOps->size() - i) + 1;
  OpsCopyInt (i, ival);   // write the relative jump count

  return 0;
}
//-------------------------------------------------------------------

int CPP_case()
{
  // stack: ( n -- | mark the beginning of a case...endcase structure)

  casestack.push_back(-1);
  return 0;
}
//-----------------------------------------------------------------

int CPP_endcase()
{
  // stack: ( -- | terminate the case...endcase structure)

  if (casestack.size() == 0) return E_V_NO_CASE;  // ENDCASE without matching CASE
  pCurrentOps->push_back(OP_DROP);

  // fix up all absolute jumps

  int i, ival;
  do
    {
      i = casestack[casestack.size()-1];
      casestack.pop_back();
      if (i == -1) break;
      ival = (int) (pCurrentOps->size() - i) + 1;
      OpsCopyInt (i, ival);   // write the relative jump count
    } while (casestack.size()) ;

  return 0;
}
//----------------------------------------------------------------

int CPP_of()
{
  // stack: ( -- | generate start of an of...endof block)

  pCurrentOps->push_back(OP_OVER);
  pCurrentOps->push_back(OP_EQ);
  pCurrentOps->push_back(OP_JZ);
  ofstack.push_back(pCurrentOps->size());
  OpsPushInt(0);   // placeholder for jump count
  pCurrentOps->push_back(OP_DROP);
  return 0;
}
//-----------------------------------------------------------------

int CPP_endof()
{
  // stack: ( -- | complete an of...endof block)

  pCurrentOps->push_back(OP_JMP);
  casestack.push_back(pCurrentOps->size());
  OpsPushInt(0);   // placeholder for jump count

  if (ofstack.empty())
    return E_V_ENDOF_NO_OF;  // ENDOF without matching OF

  int i = ofstack[ofstack.size()-1];
  ofstack.pop_back();
  int ival = (int) (pCurrentOps->size() - i) + 1;
  OpsCopyInt (i, ival);   // write the relative jump count

  return 0;
}
//-----------------------------------------------------------------

int CPP_recurse()
{
  pCurrentOps->push_back(OP_ADDR);
  if (State)
    {
      recursestack.push_back(pCurrentOps->size());
      OpsPushInt(0);
    }
  else
    {
      int ival = (int) &(*pCurrentOps)[0]; // ->begin();
      OpsPushInt(ival);
    }
  pCurrentOps->push_back(OP_EXECUTE);
  return 0;
}
//---------------------------------------------------------------------

int CPP_lbracket()
{
  State = FALSE;
  pPreviousOps = pCurrentOps;
  tempOps.erase(tempOps.begin(), tempOps.end());
  pCurrentOps = &tempOps;
  return 0;
}
//--------------------------------------------------------------------

int CPP_rbracket()
{
  pCurrentOps->push_back(OP_RET);
  if (debug) OutputForthByteCode(pCurrentOps);
  byte* pIp = GlobalIp;
  int e = vm((byte*) &(*pCurrentOps)[0]);
  pCurrentOps->erase(pCurrentOps->begin(), pCurrentOps->end());
  GlobalIp = pIp;
  State = TRUE;
  pCurrentOps = pPreviousOps;
  return e;
}
//-------------------------------------------------------------------

int CPP_does()
{
  // Allocate new opcode array

  byte* p = new byte[12];

  // Insert pfa of last word in dictionary

  p[0] = OP_ADDR;
  vector<DictionaryEntry>::iterator id = Dictionary.end() - 1;
  *((int*)(p+1)) = (int) id->Pfa;

  // Insert current instruction ptr

  p[5] = OP_ADDR;
  *((int*)(p+6)) = (int)(GlobalIp + 1);

  p[10] = OP_EXECUTE;
  p[11] = OP_RET;

  id->Cfa = (void*) p;
  id->WordCode = OP_DEFINITION;

  L_ret();
  return 0;
}
//-------------------------------------------------------------------

int CPP_immediate ()
{
  // Mark the most recently defined word as immediate.
  // stack: ( -- )

  vector<DictionaryEntry>::iterator id = Dictionary.end() - 1;
  id->Precedence |= PRECEDENCE_IMMEDIATE;
  return 0;
}
//-------------------------------------------------------------------

int CPP_nondeferred ()
{
  // Mark the most recently defined word as non-deferred.
  // stack: ( -- )

  vector<DictionaryEntry>::iterator id = Dictionary.end() - 1;
  id->Precedence |= PRECEDENCE_NON_DEFERRED;
  return 0;
}
//-------------------------------------------------------------------

int CPP_evaluate ()
{
  // Compile a string
  // ( ... a u -- ? )

  char s[256], s2[256];
  int nc = *(++GlobalSp);
  char *cp = (char*) (*(++GlobalSp));
  GlobalTp += 2;
  if (nc < 256)
    {
      memcpy (s, cp, nc);
      s[nc] = 0;
      if (*s)
	{
	  istringstream* pSS = NULL;
	  istream* pOldStream = pInStream;  // save old input stream
	  strcpy (s2, pTIB);  // save remaining part of input line in TIB
	  pSS = new istringstream(s);
	  SetForthInputStream(*pSS);
	  vector<byte> op, *pOps, *pOldOps;
	  int e;
	  pOldOps = pCurrentOps;
	  pOps = State ? pCurrentOps : &op;

	  --linecount;
	  e = ForthCompiler(pOps, &linecount);

	  // Restore the opcode vector, the input stream, and the input buffer

	  pCurrentOps = pOldOps;
	  SetForthInputStream(*pOldStream);  // restore old input stream
	  strcpy(TIB, s2);  // restore TIB with remaining input line
	  pTIB = TIB;      // restore ptr
	  delete pSS;

	}
    }
  return 0;

}
//-------------------------------------------------------------------

int CPP_source()
{
    *GlobalSp-- = (int) TIB;
    *GlobalTp-- = OP_ADDR;
    *GlobalSp-- = strlen(TIB);
    *GlobalTp-- = OP_IVAL;
    return 0;
}
//-------------------------------------------------------------------

int CPP_refill()
{
    pInStream->getline(TIB, 255);
    *GlobalSp-- = (pInStream->fail()) ? FALSE : TRUE;
    *GlobalTp-- = OP_IVAL;
    pTIB = TIB;
    return 0;
}
//-------------------------------------------------------------------

int CPP_spstore()
{
    // stack: ( addr -- | make the stack ptr point to a new address)

    DROP
    CHK_ADDR
    int* p = (int*) TOS; --p;
    if ((p > BottomOfStack) || (p < ForthStack))
        return E_V_BADSTACKADDR;  // new SP must be within its stack space
    int n = (int) (p - ForthStack);

    GlobalSp = ForthStack + n;
    GlobalTp = (byte *) ForthTypeStack + n;
    return 0;
}
//--------------------------------------------------------------------

int CPP_rpstore()
{
    // stack: ( addr -- | make the stack ptr point to a new address)

    DROP
    CHK_ADDR
    int* p = (int*) TOS; --p;
    if ((p > BottomOfReturnStack) || (p < ForthReturnStack))
        return E_V_BADSTACKADDR;  // new RP must be within its stack space

    int n = (int) (p - ForthReturnStack);
    GlobalRp = ForthReturnStack + n;
    GlobalRtp = ForthReturnTypeStack + n;
    return 0;
}

int CPP_dump ()
{
  // stack: ( a u -- | display memory; u bytes starting at address a )

  return 0;
}
//--------------------------------------------------------------------

}
