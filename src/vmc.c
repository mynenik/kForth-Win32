/*
vmc.c

C portion of the kForth virtual machine

Copyright (c) 1998--2020 Krishna Myneni and David P. Wallace, 
<krishna.myneni@ccreweb.org>

This software is provided under the terms of the GNU
Affero General Public License (AGPL), v 3.0 or later.

*/
#include<sys/types.h>
#include<sys/time.h>
#include<sys/timeb.h>
#include<sys/stat.h>
#include<stdio.h>
#include<time.h>
#include<fcntl.h>
#include<stdlib.h>
#include<math.h>
#include<windows.h>
#include<conio.h>
#include "fbc.h"
#include "kfmacros.h"

#define WSIZE 4
#define TRUE -1
#define FALSE 0
#define E_V_NOTADDR 1
#define E_V_BADCODE 6
#define E_V_STK_UNDERFLOW   7
#define E_V_QUIT  8
#define E_V_DBL_OVERFLOW  21

#define byte unsigned char

/*  Provided by ForthVM.cpp  */
extern int* GlobalSp;
extern byte* GlobalTp;
extern byte* GlobalIp;
extern int* GlobalRp;
extern byte* GlobalRtp;
extern int* BottomOfStack;
extern int* BottomOfReturnStack;
extern byte* BottomOfTypeStack;
extern byte* BottomOfReturnTypeStack;
extern int CPP_bye();

/* Provided by vm32.asm */
extern int Base;
extern int State;
extern char* pTIB;
extern int NumberCount;
extern int JumpTable[];
extern char WordBuf[];
extern char TIB[];
extern char NumberBuf[];
extern char ParseBuf[];

extern int L_dnegate();
extern int L_dplus();
extern int L_dminus();
extern int L_udmstar();
extern int L_utmslash();
extern int L_quit();
extern int L_abort();
extern int vm(byte*);

// struct timeval ForthStartTime;
unsigned long int ForthStartTime;
double* pf;
double f;
char temp_str[256];

#define DOUBLE_FUNC(x)   pf = (double*)(GlobalSp+1); *pf=x(*pf);

int C_ftan  () { DOUBLE_FUNC(tan)  return 0; }
int C_facos () { DOUBLE_FUNC(acos) return 0; }
int C_fasin () { DOUBLE_FUNC(asin) return 0; }
int C_fatan () { DOUBLE_FUNC(atan) return 0; }
int C_fsinh () { DOUBLE_FUNC(sinh) return 0; }
int C_fcosh () { DOUBLE_FUNC(cosh) return 0; }
int C_ftanh () { DOUBLE_FUNC(tanh) return 0; }
int C_fasinh () { DOUBLE_FUNC(asinh) return 0; }
int C_facosh () { DOUBLE_FUNC(acosh) return 0; }
int C_fatanh () { DOUBLE_FUNC(atanh) return 0; }
int C_fexp  () { DOUBLE_FUNC(exp)   return 0; }
int C_fexpm1() { DOUBLE_FUNC(expm1) return 0; }
int C_fln   () { DOUBLE_FUNC(log)   return 0; }
int C_flnp1 () { DOUBLE_FUNC(log1p) return 0; }
int C_flog  () { DOUBLE_FUNC(log10) return 0; }
// int C_falog () { DOUBLE_FUNC(exp10) return 0; }

int C_falog ()
{
     pf = (double*)(GlobalSp + 1);
     f = *pf;
     *pf = pow(10., f);
     return 0;
}
     
// powA  is copied from the source of the function pow() in paranoia.c,
//   at  http://www.math.utah.edu/~beebe/software/ieee/
double powA(double x, double y) /* return x ^ y (exponentiation) */
{
    double xy, ye;
    long i;
    int ex, ey = 0, flip = 0;

    if (!y) return 1.0;

    if ((y < -1100. || y > 1100.) && x != -1.) return exp(y * log(x));

    if (y < 0.) { y = -y; flip = 1; }
    y = modf(y, &ye);
    if (y) xy = exp(y * log(x));
    else xy = 1.0;
    /* next several lines assume >= 32 bit integers */
    x = frexp(x, &ex);
    if ((i = (long)ye, i)) for(;;) {
        if (i & 1) { xy *= x; ey += ex; }
        if (!(i >>= 1)) break;
        x *= x;
        ex *= 2;
        if (x < .5) { x *= 2.; ex -= 1; }
    }
    if (flip) { xy = 1. / xy; ey = -ey; }
    return ldexp(xy, ey);
}

int C_fpow ()
{
	pf = (double*)(GlobalSp + 1);
	f = *pf;
	++pf;
	*pf = powA (*pf, f);
	GlobalSp += 2;
	INC2_DTSP
	return 0;
}				

int C_fmin ()
{
	pf = (double*)(GlobalSp + 1);
	f = *pf;
	++pf;
	if (f < *pf) *pf = f;
	GlobalSp += 2;
	GlobalTp += 2;
	return 0;
}

int C_fmax ()
{
	pf = (double*)(GlobalSp + 1);
	f = *pf;
	++pf;
	if (f > *pf) *pf = f;
	GlobalSp += 2;
	GlobalTp += 2;
	return 0;
}

// Allocate virtual read-write memory; return start address
// if successful, or -1 on error.
int C_valloc ()
{
  /* stack: ( anew usize ntype nprot -- a|0 ) */
  
  DROP
  long int np = TOS;
  DROP
  long int nt = TOS;
  DROP
  unsigned long int u = (unsigned long int) TOS;
  DROP
  unsigned long int au = (unsigned long int) TOS;

  void* p = VirtualAlloc( au, u, nt, np );
		
  if (p == 0) p = -1;
  TOS = (int) p;
  DEC_DSP
  STD_ADDR  
  return 0;
}

// Free virtual memory previously allocated with VALLOCATE.
// Return 0 on success.
int C_vfree ()
{
   /* stack: ( a -- ior ) */
   DROP
   void* p = TOS;  // <== fixme ==  check address!
   bool b = VirtualFree( p, 0, MEM_RELEASE );
   TOS = (!b);
   DEC_DSP
   STD_IVAL
   return 0;
}

// Set protection for virtual memory region starting at
// address a and usize bytes. The new protection value
// is newprot, and aoldprot is the address for storing
// the old protection value. Return 0 on success.
int C_vprotect ()
{
   /* stack: ( a usize newprot aoldprot -- ior ) */
   DROP
   long int* aop = TOS;  // <== fixme == check address!
   DROP
   unsigned long int np = TOS;
   DROP
   unsigned long int u = TOS;
   DROP
   void* p = (void*) TOS;  // <== fixme == check address!
   bool b = VirtualProtect( p, u, np, aop );
   TOS = (!b);
   DEC_DSP
   STD_IVAL
   return 0;
} 

int C_open ()
{
  /* stack: ( ^str flags -- fd | return the file descriptor )
     ^str is a counted string with the pathname, flags
     indicates the method of opening (read, write, etc.)  */

  int flags, mode = 0, fd;
  char* pname;

  ++GlobalSp; ++GlobalTp;
  flags = *GlobalSp;
  ++GlobalSp; ++GlobalTp;
  if (*GlobalTp == OP_ADDR)
    {
      pname = *((char**)GlobalSp);
      ++pname;
//      if (flags & O_CREAT) mode = S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH;
      if (flags & O_CREAT) mode = _S_IREAD | _S_IWRITE ;
      fd = open (pname, flags, mode);
      *GlobalSp-- = fd;
      *GlobalTp-- = OP_IVAL;
      return 0;
    }
  else
    return 1;  /* not an address error */
}
      
int C_lseek ()
{
  /* stack: ( fd offset mode -- error | set file position in fd ) */

  int fd, offset, mode;
  ++GlobalSp; ++GlobalTp;
  mode = *GlobalSp++; ++GlobalTp;
  offset = *GlobalSp++;
  fd = *GlobalSp;
  *GlobalSp-- = lseek (fd, offset, mode);
  return 0;
}

int C_close ()
{

  /* stack: ( fd -- err | close the specified file and return error code ) */

  int fd;
  ++GlobalSp;
  fd = *GlobalSp;
  *GlobalSp-- = close(fd);
  return 0;
}

int C_read ()
{
  /* stack: ( fd buf count -- length | read count bytes into buf from fd ) */
  int fd, count;
  void* buf;

  ++GlobalSp; ++GlobalTp;
  count = *GlobalSp++; ++GlobalTp;
  if (*GlobalTp == OP_ADDR)
    {      
      buf = *((void**)GlobalSp);
      ++GlobalSp; ++GlobalTp;
      fd = *GlobalSp;
      *GlobalSp-- = read (fd, buf, count);
      *GlobalTp-- = OP_IVAL;
      return 0;
    }
  else
    return 1;  /* not an address error */
}

int C_write ()
{
  /* stack: ( fd buf count  -- length | write count bytes from buf to fd ) */
  int fd, count;
  void* buf;

  ++GlobalSp; ++GlobalTp;
  count = *GlobalSp++; ++GlobalTp;
  if (*GlobalTp == OP_ADDR)
    {
      buf = *((void**)GlobalSp);
      ++GlobalSp; ++GlobalTp;
      fd = *GlobalSp;
      *GlobalSp-- = write (fd, buf, count);
      *GlobalTp-- = OP_IVAL;
      return 0;
    }
  else
    return 1;  /* not an address error */
}

// FSYNC ( fd -- ior )
// Flush all buffered data written to file to the storage device
// Low-level interface for implementation of standard Forth
// word, FLUSH-FILE (Forth 94/Forth 2012)
int C_fsync ()
{
  int fd;
  int* pH;
  int e;
  DROP
  fd = TOS;
  pH = _get_osfhandle(fd);
  e = (FlushFileBuffers(pH) == 0);
  PUSH_IVAL( e )
  return 0;
}

int C_ioctl ()
{
  /* stack: ( handle request ain nbin aout nbout -- err | device control function ) */
  int handle, request, nbin, nbout, success, nbret;
  char *inbuf, *outbuf;
  
  ++GlobalSp; ++GlobalTp;
  nbout = *GlobalSp++; GlobalTp++;
  outbuf  = *((char**) GlobalSp);
  GlobalSp++;GlobalTp++;
  nbin  = *GlobalSp++; GlobalTp++;
  inbuf = *((char**) GlobalSp);
  GlobalSp++; GlobalTp++;
  request = *GlobalSp++; GlobalTp++;
  handle = *GlobalSp;
  success = DeviceIoControl(handle, request, inbuf, nbin, outbuf, nbout,
		  &nbret, NULL);
  *GlobalSp-- = !success;
  return 0;
}
/*----------------------------------------------------------*/

int C_dlopen ()
{
   /* stack: ( azLibName flag -- handle | NULL) */
   unsigned flags;
   HMODULE handle;
   char *pLibName;

   DROP
   flags = TOS;   // flags is ignored
   DROP
   CHK_ADDR
   pLibName = *((char**) GlobalSp);  // pointer to a null-terminated string

   handle = LoadLibraryA((LPCSTR) pLibName);
   PUSH_IVAL((int) handle)
   return 0;
}

int C_dlerror ()
{
   /* stack: ( -- addrz) ; Returns address of null-terminated string*/
   static char errMsg[16];
   memset(errMsg, 0, 16);
   long int ecode = GetLastError();
   _snprintf(errMsg, 15, "Error  %d", ecode);
   errMsg[15] = 0; 
   PUSH_ADDR((int) errMsg)
   return 0;
}

int C_dlsym ()
{
    /* stack: ( handle azsymbol -- addr ) */
    HMODULE handle;
    char *pSymbol;
    void *pSymAddr;

    DROP
    CHK_ADDR
    pSymbol = *((char**)GlobalSp);  // pointer to a null-terminated string
    DROP
    handle = TOS;

    pSymAddr = GetProcAddress(handle, (const char*) pSymbol);
    PUSH_ADDR((int) pSymAddr)
    return 0;
}

int C_dlclose ()
{
    /* stack: ( handle -- error | 0) */
    HMODULE handle;
    INC_DSP
    handle = TOS;
    TOS = ( FreeLibrary(handle) == 0) ;
    DEC_DSP
    return 0;
}

void save_term ()
{
  ;
}

void restore_term ()
{
  ;
}

void echo_off ()
{
  ;
}

void echo_on ()
{
  ;
}

int C_key ()
{
  /* stack: ( -- n | wait for keypress and return key code ) */

  HANDLE hStdIn;
  INPUT_RECORD inBuf;
  unsigned long ch, n=0;

  hStdIn = GetStdHandle(STD_INPUT_HANDLE);
   while (n < 1) {
     if (ReadConsoleInput( hStdIn, &inBuf, 1, &n )) {
       if ((inBuf.EventType == KEY_EVENT) && 
           (inBuf.Event.KeyEvent.bKeyDown) &&
	   (inBuf.Event.KeyEvent.uChar.AsciiChar))
          ch = (unsigned long) inBuf.Event.KeyEvent.uChar.AsciiChar;
        else
          n = 0;
     }
   }
   *GlobalSp-- = ch;
   *GlobalTp-- = OP_IVAL;
 
   return 0;
}
/*----------------------------------------------------------*/

int C_keyquery ()
{
  /* stack: ( -- b | return true if a key is available ) */

  HANDLE hStdIn;
  INPUT_RECORD inBuf;
  unsigned long n, key_available;

  hStdIn = GetStdHandle(STD_INPUT_HANDLE);
  PeekConsoleInput( hStdIn, &inBuf, 1, &n );
  key_available = ((inBuf.EventType == KEY_EVENT) &&
      (inBuf.Event.KeyEvent.bKeyDown) &&
      (inBuf.Event.KeyEvent.uChar.AsciiChar));

  *GlobalSp-- = key_available ? -1 : 0;
  *GlobalTp-- = OP_IVAL;
  return 0;
}      
/*----------------------------------------------------------*/

int C_accept ()
{
  /* stack: ( a n1 -- n2 | wait for n characters to be received ) */

  HANDLE hStdOut;
  char ch, *cp, *cpstart, *bksp = "\010 \010";
  int n1, n2, nr, nw;

  hStdOut = GetStdHandle(STD_OUTPUT_HANDLE);
  ++GlobalSp; ++GlobalTp;
  n1 = *GlobalSp++; ++GlobalTp;
  if (*GlobalTp != OP_ADDR) return 1;
  cp = *((char**)GlobalSp);
  cpstart = cp;

  n2 = 0;
  while (n2 < n1)
    {
      C_key();
      *cp = *(++GlobalSp); ++GlobalTp;
      if (*cp == 13) 
 	break;
      else if (*cp == 8) {
        --cp; --n2;
        if ((cp < cpstart) || (n2 < 0))  { 
	  n2 = 0;
	  cp = cpstart;
	}
	else
	  // write (0, bksp, 3);
	  WriteConsole(hStdOut, bksp, 3, &nw, NULL);
       }
       else {
	  // write (0, cp, 1);
	  WriteConsole(hStdOut, cp, 1, &nw, NULL);
	  ++n2; ++cp;
        }
    }
  *GlobalSp-- = n2;
  *GlobalTp-- = OP_IVAL;
  return 0;
}

/*----------------------------------------------------------*/

char* ExtractName (char* str, char* name)
{
/*
Starting at ptr str, extract the non delimiter text into
a buffer starting at name with null terminator appended
at the end. Return a pointer to the next position in str.
*/

    const char* delim = "\n\r\t ";
    char *pStr = str, *pName = name;

    if (*pStr)
      {
        while (strchr(delim, *pStr)) ++pStr;
        while (*pStr && (strchr(delim, *pStr) == NULL))
          {
            *pName = *pStr;
            ++pName;
            ++pStr;
          }
      }
    *pName = 0;
    return pStr;
}
/*----------------------------------------------------------*/

int IsFloat (char* token, double* p)
{
/*
Check the string token to see if it is an LMI style floating point
number; if so set the value of *p and return True, otherwise
return False.
*/
    char *pStr = token;

    if (strchr(pStr, 'E'))
    {
        while ((isdigit(*pStr)) || (*pStr == '-')
          || (*pStr == 'E') || (*pStr == '+') || (*pStr == '.'))
        {
            ++pStr;
        }
        if (*pStr == 0)
        {
            /* LMI Forth style */

            --pStr;
            if (*pStr == 'E') *pStr = '\0';
            *p = atof(token);
            return TRUE;
        }
    }

    return FALSE;
}
/*----------------------------------------------------------*/

int isBaseDigit (int c)
{
   int u = toupper(c);

   return ( (isdigit(u) && ((u - 48) < Base)) ||
            (isalpha(u) && (Base > 10) && ((u - 55) < Base)) );
}
/*---------------------------------------------------------*/

int IsInt (char* token, int* p)
{
/* Check the string token to see if it is an integer number;
   if so set the value of *p and return True, otherwise return False.
Note: strtoul() behavior is different between gcc and dmc compilers.
*/

  int b = FALSE, sign = FALSE;
  unsigned u = 0;
  char *pStr = token, *sos = token, *endp;

  if ((*pStr == '-') || isBaseDigit(*pStr))
    {
      if (*pStr == '-') {sign = TRUE; ++sos;}
      ++pStr;
      while (isBaseDigit(*pStr))
        {
          ++pStr;
        }
      if (*pStr == 0)
        {
          u = strtoul(sos, &endp, Base);
          b = TRUE;
        }

    }
  
  *p = (sign) ? -((signed int) u) : u ;
  return b;
}
/*---------------------------------------------------------*/

int C_word ()
{
  /* stack: ( n -- ^str | parse next word in input stream )
     n is the delimiting character and ^str is a counted string. */
  DROP
  char delim = TOS;
  char *dp = WordBuf + 1;

  while (*pTIB)  /* skip leading delimiters */
    {
      if (*pTIB != delim) break;
      ++pTIB;
    }
  if (*pTIB)
    {
      int count = 0;
      while (*pTIB)
        {
          if (*pTIB == delim) break;
          *dp++ = *pTIB++;
          ++count;
        }
      if (*pTIB) ++pTIB;  /* consume the delimiter */
      *WordBuf = count;
      *dp = ' ';
    }
  else
    {
      *WordBuf = 0;
    }
  PUSH_ADDR((int) WordBuf)
  return 0;
}

int C_parse ()
{
  /* stack: ( n -- a u | parse string delimited by char n ) */
  DROP
  char delim = TOS;
  char *dp = ParseBuf;
  int count = 0;
  if (*pTIB)
    {

      while (*pTIB)
        {
          if (*pTIB == delim) break;
          *dp++ = *pTIB++;
          ++count;
        }
      if (*pTIB) ++pTIB;  /* consume the delimiter */
    }
  PUSH_ADDR((int) ParseBuf)
  PUSH_IVAL(count)
  return 0;
}
/*----------------------------------------------------------*/

int C_trailing ()
{
  /* stack: ( a n1 -- a n2 | adjust count n1 to remove trailing spaces ) */
  int n1;
  char *cp;
  DROP
  n1 = TOS;
  if (n1 > 0) {
    DROP
    CHK_ADDR
    cp = (char *) TOS + n1 - 1;
    while ((*cp == ' ') && (n1 > 0)) { --n1; --cp; }
    DEC_DSP
    DEC_DTSP
    TOS = n1;
  }
  DEC_DSP
  DEC_DTSP
  return 0;
}
/*----------------------------------------------------------*/

int C_bracketsharp()
{
  /* stack: ( -- | initialize for number conversion ) */

  NumberCount = 0;
  NumberBuf[255] = 0;
  return 0;
}


int C_sharp()
{
  /* stack: ( ud1 -- ud2 | convert one digit of ud1 ) */

  unsigned int u1, u2, rem;
  char ch;

  *GlobalSp = *(GlobalSp+2); --GlobalSp;
  *GlobalSp = *(GlobalSp+2); --GlobalSp;  /* 2dup */
  *GlobalTp = *(GlobalTp+2); --GlobalTp;
  *GlobalTp = *(GlobalTp+2); --GlobalTp;  /*  "  */
  TOS = 0; /* pad to triple length */
  DEC_DSP
  DEC_DTSP
  TOS = Base;
  DEC_DSP
  DEC_DTSP

  L_utmslash();
  u1 = *(GlobalSp + 1);  /* quotient */
  u2 = *(GlobalSp + 2);

  /* quotient is on the stack; we need the remainder */

  TOS = Base;
  DEC_DSP
  DEC_DTSP
  L_udmstar();
  DROP

  L_dminus();
  rem = *(GlobalSp + 2);  /* get the remainder */

  *(GlobalSp + 1) = u1;   /* replace rem with quotient on the stack */
  *(GlobalSp + 2) = u2;
  ch = (rem < 10) ? (rem + 48) : (rem + 55);
  ++NumberCount;
  NumberBuf[255 - NumberCount] = ch;

  return 0;
}

int C_sharps()
{
  /* stack: ( ud -- 0 0 | finish converting all digits of ud ) */

  unsigned int u1=1, u2=0;

  while (u1 | u2)
    {
      C_sharp();
      u1 = *(GlobalSp + 1);
      u2 = *(GlobalSp + 2);
    }
  return 0;
}


int C_hold()
{
  /* stack: ( n -- | insert character into number string )  */
  DROP
  char ch = TOS;
  ++NumberCount;
  NumberBuf[255-NumberCount] = ch;
  return 0;
}


int C_sign()
{
  /* stack: ( n -- | insert sign into number string if n < 0 ) */
  DROP
  int n = TOS;
  if (n < 0)
    {
      ++NumberCount;
      NumberBuf[255-NumberCount] = '-';
    }
  return 0;
}

int C_sharpbracket()
{
  /* stack: ( ud -- a u | complete number conversion ) */

  DROP
  DROP
  PUSH_ADDR( (int) (NumberBuf + 255 - NumberCount) )
  PUSH_IVAL(NumberCount)
  return 0;
}
/*--------------------------------------------------------------*/

int C_tonumber ()
{
  /* stack: ( ud1 a1 u1 -- ud2 a2 u2 | translate characters into ud number ) */

  unsigned i, ulen, uc;
  int c;
  char *cp;
  ulen = (unsigned) *(GlobalSp + 1);
  if (ulen == 0) return 0;
  uc = ulen;
  DROP
  DROP
  CHK_ADDR
  cp = (char*) TOS;
  for (i = 0; i < ulen; i++) {
        c = (int) *cp;
        if (!isBaseDigit(c)) break;
        if (c > '9') {
          c &= 223;
          c -= 'A';
          c += 10;
        }
        else c -= '0';
        TOS = Base;
        DEC_DSP
        DEC_DTSP
        L_udmstar();
        DROP 
        if (TOS) return E_V_DBL_OVERFLOW;
        TOS = c;
        DEC_DSP
        TOS = 0;
        DEC_DSP
        DEC_DTSP
        DEC_DTSP
        L_dplus();
        --uc; ++cp;
  }

  TOS = (int) cp;
  DEC_DSP
  TOS = uc;
  DEC_DSP
  DEC_DTSP;
  DEC_DTSP;

  return 0;
}
/*-----------------------------------------------------------*/

int C_numberquery ()
{
  /* stack: ( ^str -- d b | translate characters into number using current base ) */

  char *pStr;
  int b, sign, nc;

  b = FALSE;
  sign = FALSE;

  DROP
  if (GlobalSp > BottomOfStack) return E_V_STK_UNDERFLOW;
  CHK_ADDR
  pStr = *((char**)GlobalSp);
  PUSH_IVAL(0)
  PUSH_IVAL(0)
  nc = *pStr;
  ++pStr;

  if (*pStr == '-') {
    sign = TRUE; ++pStr; --nc;
  }
  if (nc > 0) {
        PUSH_ADDR((int) pStr)
        PUSH_IVAL(nc)
        C_tonumber();
        DROP
        b = TOS;
        DROP
        b = (b == 0) ? TRUE : FALSE ;
  }

  if (sign) L_dnegate();

  PUSH_IVAL(b)
  return 0;
}
/*----------------------------------------------------------*/

int C_tofloat ()
{
  /* stack: ( a u -- f true | false ; convert string to floating point number ) */

  char s[256], *cp;
  double f;
  unsigned nc, u;
  int b;

  DROP
  nc = TOS;
  DROP
  cp = (char*) TOS;

  b = FALSE; f = 0.;

  if (nc < 256) {
      /* check for a string of blanks */
      u = nc;
      while ((*(cp+u-1) == ' ') && u ) --u;
      if (u == 0) { /* Forth-94 spec:  */
        b = TRUE;    /* "A string of blanks is a special case representing zero."  */
      }              /* "A null string will be converted as a valid 0E."  */
      else {
        /* Verify there is a numeric digit in the string */
        u = 0;
        for (u = 0; u < nc; ++u) if (isdigit(*(cp+u))) break;
        if (u == nc) {
          b = FALSE;                   /* no numeric digit in string */
        }
        else {
          memcpy (s, cp, nc);
          s[nc] = 0;
          strupr(s);

          /* Replace 'D' with 'E'  (Fortran double precision float exponent indicator) */
          for (u = 0; u < nc; u++)
            if (s[u] == 'D') s[u] = 'E';

          /* '+' and '-' may also be indicators of the exponent if
             they are used internally, following the significand; 
             Replace with or insert 'E', as appropriate */

          if ((! strchr(s, 'E')) && (nc > 2)) {
            for (u = 1; u < (nc-1); u++) {
              if (s[u] == '+') {
                if ((isdigit(s[u-1]) || s[u-1] =='.') && isdigit(s[u+1])) s[u] = 'E';
                }
              else if (s[u] == '-')
                {
                   if ((isdigit(s[u-1]) || s[u-1] =='.') && isdigit(s[u+1])) {
                      memmove(s+u+1, s+u, nc-u+1);
                      s[u]='E';
                   }
                 }
               else
                 ;
             }
          }

          /* Tack on power of ten (0), if it is missing */
          if (! strchr(s, 'E')) strcat(s, "E0");
          if (s[0]) b = IsFloat(s, &f);
        }
      }
    }


  if (b) {
      DEC_DSP
      *((double*)(GlobalSp)) = f;
      DEC_DSP
      STD_IVAL
      STD_IVAL
  }
  PUSH_IVAL(b)
  return 0;
}
/*-------------------------------------------------------------*/

int C_system ()
{
  /* stack: ( ^str -- n )
   *  n is the exit code for the process, or -1 if process
   *  could not be launched or its exit code could not be obtained. */

  char* cp;
  int nc, nr, ec;
  STARTUPINFO si;
  PROCESS_INFORMATION pi;

  ++GlobalSp; ++GlobalTp;
  if (*GlobalTp != OP_ADDR) return 1;     /* VM error: not an address */
  cp = (char*) (*GlobalSp);
  nc = *cp;
  strncpy (temp_str, cp+1, nc);
  temp_str[nc] = 0;

  ZeroMemory(&si, sizeof(si));
  si.cb = sizeof(si);
  ZeroMemory(&pi, sizeof(pi));
  nr = CreateProcess(NULL, temp_str,NULL,NULL,FALSE,0,NULL,NULL,&si,&pi);
  if (nr) {
    /* Process creation succeeded; wait for child exit */
    WaitForSingleObject(pi.hProcess, INFINITE);
    nr = GetExitCodeProcess(pi.hProcess, &ec);
    if (nr == 0) ec = -1;
    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);

  }
  else
    ec = -1;
    
  *GlobalSp-- = ec;
  *GlobalTp-- = OP_IVAL;
  return 0;
}
/*----------------------------------------------------------*/

int C_chdir ()
{
  /* stack: ( ^path -- n | set working directory to ^path; return error code ) */

  char* cp;
  int nc;

  ++GlobalSp; ++GlobalTp;
  if (*GlobalTp != OP_ADDR) return 1;
  cp = (char*)(*GlobalSp);
  nc = *cp;
  strncpy (temp_str, cp+1, nc);
  temp_str[nc] = 0;
  *GlobalSp-- = chdir(temp_str);
  *GlobalTp-- = OP_IVAL;
  return 0;
}
/*-----------------------------------------------------------*/

int C_timeanddate ()
{
  /* stack: ( -- sec min hr day mo yr | fetch local time ) */

  time_t t;
  struct tm t_loc;

  time (&t);
  t_loc = *(localtime (&t));

  *GlobalSp-- = t_loc.tm_sec; *GlobalTp-- = OP_IVAL;
  *GlobalSp-- = t_loc.tm_min; *GlobalTp-- = OP_IVAL;
  *GlobalSp-- = t_loc.tm_hour; *GlobalTp-- = OP_IVAL;
  *GlobalSp-- = t_loc.tm_mday; *GlobalTp-- = OP_IVAL;
  *GlobalSp-- = 1 + t_loc.tm_mon; *GlobalTp-- = OP_IVAL;
  *GlobalSp-- = 1900 + t_loc.tm_year; *GlobalTp-- = OP_IVAL;

  return 0;
}
/*------------------------------------------------------*/

void set_start_time ()
{
  /* this is not a word in the Forth dictionary; it is
     used by the initialization routine on startup     */

  // gettimeofday (&ForthStartTime, NULL);
  ForthStartTime = GetTickCount();

}

int C_msfetch ()
{
  /* stack: ( -- msec | return msec elapsed since start of Forth ) */
  
  // struct timeval tv;
  // gettimeofday (&tv, NULL);
  // *GlobalSp-- = (tv.tv_sec - ForthStartTime.tv_sec)*1000 + 
  // (tv.tv_usec - ForthStartTime.tv_usec)/1000;
  *GlobalSp-- = GetTickCount() - ForthStartTime;
  *GlobalTp-- = OP_IVAL;
  return 0;
}
/*------------------------------------------------------*/

int C_search ()
{
  /* stack: ( a1 u1 a2 u2 -- a3 u3 flag ) */

  char *str1, *str2, *cp, *cp2;
  unsigned int n, n_needle, n_haystack, n_off, n_rem;
  DROP
  n = TOS;
  DROP
  CHK_ADDR
  str2 = (char*) TOS;
  DROP
  if (n > 255) n = 255;
  n_needle = n;
  n_haystack = TOS;    // size of search buffer
  DROP
  CHK_ADDR
  str1 = (char*) TOS;
  n_rem = n_haystack;
  n_off = 0;
  cp = str1;
  cp2 = NULL;

  if (n_needle > 0)
  {
      while (n_rem >= n_needle)
      {
          cp = (char *) memchr(cp, *str2, n_rem);
          if (cp && (n_rem >= n_needle))
          {
              n_rem = n_haystack - (cp - str1);
              if (memcmp(cp, str2, n_needle) == 0)
              {
                  cp2 = cp;
                  n_off = (int)(cp - str1);
                  break;
              }
              else
              {
                  ++cp; --n_rem;
              }
          }
          else
              n_rem = 0;
      }
  }
  else if (n_needle == 0)
        cp2 = cp;

  else
    ;

  if (cp2 == NULL) n_off = 0;
  TOS = (int)(str1 + n_off);
  DEC_DSP
  TOS = n_haystack - n_off;
  DEC_DSP
  TOS = cp2 ? -1 : 0 ;
  DEC_DSP
  STD_ADDR
  STD_IVAL
  STD_IVAL

  return 0;
}
/*------------------------------------------------------*/

int C_compare ()
{
  /* stack: ( a1 u1 a2 u2 -- n ) */

  char *str1, *str2;
  int n1, n2, n, ncmp, nmin;
  DROP
  n2 = TOS;
  DROP
  CHK_ADDR
  str2 = (char*) TOS;
  DROP
  n1 = TOS;
  DROP
  CHK_ADDR
  str1 = (char*) TOS;

  nmin = (n1 < n2) ? n1 : n2;
  ncmp = memcmp(str1, str2, nmin);

  if (ncmp == 0) {
    if (n1 == n2) n = 0;
    else if (n1 < n2) n = -1;
    else n = 1;
  }
  else if (ncmp < 0)  n = -1;
  else n = 1;

  PUSH_IVAL(n)
  return 0;
}
/*------------------------------------------------------*/
