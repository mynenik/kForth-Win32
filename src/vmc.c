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
#define E_V_STK_UNDERFLOW   7
#define E_V_QUIT  8

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

extern int Base;
extern int State;
extern char* pTIB;
extern int JumpTable[];

int L_dnegate();

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

int C_ioctl ()
{
  /* stack: ( fd request addr -- err | device control function ) */
  int fd, request;
  char* argp;

  ++GlobalSp; ++GlobalTp;
  argp = *((char**) GlobalSp);  /* don't do type checking on argp */
  ++GlobalSp; ++GlobalTp;
  request = *GlobalSp++;
  fd = *GlobalSp;
  *GlobalSp-- = -1; // ioctl(fd, request, argp);
  return 0;
}
/*----------------------------------------------------------*/

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

int C_numberquery ()
{
  /* stack: ( a -- d b | translate characters into number using current base ) */

  char *token, *pStr, *endp;
  int b, sign;
  int n;

  ++GlobalSp; ++GlobalTp;
  if (GlobalSp > BottomOfStack) return 7; /* stack underflow */
  if (*GlobalTp != OP_ADDR) return 1;     /* VM error: not an address */
  token = *((char**)GlobalSp);
  ++token;
  pStr = token;
  n = 0;
  sign = FALSE;
  b = FALSE;

  if ((*pStr == '-') || isdigit(*pStr) || (isalpha(*pStr) && (Base > 10)
					   && ((*pStr - 55) < Base)))
    {
      if (*pStr == '-') {sign = TRUE;}
      ++pStr;
      while (isdigit(*pStr) || (isalpha(*pStr) && (Base > 10) &&
				((*pStr - 55) < Base)))	    
	{
	  ++pStr;
	}
      if (*pStr == 0)
        {
	  n = strtol(token, &endp, Base);
	  b = TRUE;
        }

    }

  *GlobalSp-- = n;
  *GlobalTp-- = OP_IVAL;
  *GlobalSp-- = sign;
  *GlobalTp-- = OP_IVAL;
  *GlobalSp-- = b;
  *GlobalTp-- = OP_IVAL;  
  return 0;
}
/*----------------------------------------------------------*/

int C_system ()
{
  /* stack: ( ^str -- n | n is the return code for the command in ^str ) */

  char* cp;
  int nc, nr, ec;

  ++GlobalSp; ++GlobalTp;
  if (*GlobalTp != OP_ADDR) return 1;     /* VM error: not an address */
  cp = (char*) (*GlobalSp);
  nc = *cp;
  strncpy (temp_str, cp+1, nc);
  temp_str[nc] = 0;
  nr = WinExec(temp_str, SW_SHOW);
  ec = (nr > 31) ? 0 : -1;    /* WinExec return code > 31 means no error */
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
  ++GlobalSp; ++GlobalTp;
  n = *GlobalSp;
  ++GlobalSp; ++GlobalTp;
  if (*GlobalTp != OP_ADDR) return E_V_NOTADDR;
  str2 = (char*)(*GlobalSp++); ++GlobalTp;
  if (n > 255) n = 255;
  n_needle = n;
  n_haystack = *GlobalSp++; ++GlobalTp;  // size of search buffer
  if (*GlobalTp != OP_ADDR) return E_V_NOTADDR;
  str1 = (char*)(*GlobalSp);  
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

  if (cp2 == NULL) n_off = 0;
  *GlobalSp-- = (int)(str1 + n_off); *GlobalTp-- = OP_ADDR;
  *GlobalSp-- = n_haystack - n_off; *GlobalTp-- = OP_IVAL;
  *GlobalSp-- = cp2 ? -1 : 0 ; *GlobalTp-- = OP_IVAL;

  return 0;
}
/*------------------------------------------------------*/

int C_compare ()
{
  /* stack: ( a1 u1 a2 u2 -- n ) */

  char *str1, *str2;
  int n1, n2, n, ncmp, nmin;
  ++GlobalSp; ++GlobalTp;
  n2 = *GlobalSp;
  ++GlobalSp; ++GlobalTp;
  if (*GlobalTp != OP_ADDR) return E_V_NOTADDR;
  str2 = (char*)(*GlobalSp++); ++GlobalTp;
  n1 = *GlobalSp++; ++GlobalTp;
  if (*GlobalTp != OP_ADDR) return E_V_NOTADDR;
  str1 = (char*)(*GlobalSp);

  if ((n1 <= 0) || (n2 <= 0))
  {
      n = -1;
  }
  else
  {
      nmin = (n1 < n2) ? n1 : n2;
      ncmp = memcmp(str1, str2, nmin);

      if (ncmp == 0)
      {
	  if (n1 == n2) n = 0;
	  else if (n1 < n2) n = -1;
	  else n = 1;
      }
      else if (ncmp < 0)  n = -1;
      else n = 1;
  }
  *GlobalSp-- = n; *GlobalTp-- = OP_IVAL;
  return 0;
}
/*------------------------------------------------------*/
