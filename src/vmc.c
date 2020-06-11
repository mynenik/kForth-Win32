/*
vmc.c

C portion of the kForth virtual machine
Copyright (c) 1998--2001 Krishna Myneni and David P. Wallace, 
Creative Consulting for Research and Education

Revisions:
	9-27-1998 -- created.
	3-1-1999  -- added C_open, C_lseek, C_close, C_read, C_write
	3-2-1999  -- fixed C_open, added C_ioctl
	5-27-1999 -- added C_key, C_accept
	6-09-1999 -- added C_numberquery
	6-12-1999 -- fixed sign for C_numberquery
	7-14-1999 -- fixed C_numberquery to reject junk for base > 10
	9-12-1999 -- added C_system
	10-7-1999 -- added C_chdir
	10-9-1999 -- added C_timeanddate
	10-28-1999 -- added C_keyquery
	02-19-2001 -- modified C_keyquery function to fix problems with Win/GNU
	09-19-2001 -- modified C_accept to handle backspace key
	09-05-2002 -- added C_search, C_compare, and C_msfetch
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

#define OP_IVAL 'I'
#define OP_ADDR 'A'
#define WSIZE 4
#define TRUE -1
#define FALSE 0
#define E_V_NOTADDR 1
#define E_V_STK_UNDERFLOW   7
#define byte unsigned char

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

// struct timeval ForthStartTime;
unsigned long int ForthStartTime;
double* pf;
double f;
char temp_str[256];
char key_query_char = 0;

int C_ftan ()
{
	pf  = (double*)(GlobalSp + 1);
	*pf = tan(*pf);
	return 0;
}

int C_facos ()
{
	pf = (double*)(GlobalSp + 1);
	*pf = acos(*pf);	
	return 0;
}

int C_fasin ()
{
	pf = (double*)(GlobalSp + 1);
	*pf = asin(*pf);
	return 0;
}

int C_fatan ()
{
	pf = (double*)(GlobalSp + 1);
	*pf = atan(*pf);
	return 0;
}

int C_fexp ()
{
	pf = (double*)(GlobalSp + 1);
	*pf = exp(*pf);
	return 0;
}

int C_fln ()
{
	pf = (double*)(GlobalSp + 1);
	*pf = log(*pf);
	return 0;
}

int C_flog ()
{
	pf = (double*)(GlobalSp + 1);
	*pf = log10(*pf);	
	return 0;
}

int C_fpow ()
{
	pf = (double*)(GlobalSp + 1);
	f = *pf;
	++pf;
	*pf = pow (*pf, f);
	GlobalSp += 2;
	GlobalTp += 2;
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

  char ch;
  int n;
//  struct termios t1, t2;

  if (key_query_char)
    {
      ch = key_query_char;
      key_query_char = 0;
    }
  else
    {
//      tcgetattr(0, &t1);
//      t2 = t1;
//      t2.c_lflag &= ~ICANON;
//      t2.c_lflag &= ~ECHO;
//      t2.c_cc[VMIN] = 1;
//      t2.c_cc[VTIME] = 0;
//      tcsetattr(0, TCSANOW, &t2);

      do {
	n = read(0, &ch, 1);
      } while (n != 1);

//      tcsetattr(0, TCSANOW, &t1);
    }

  *GlobalSp-- = ch;
  *GlobalTp-- = OP_IVAL;
 
  return 0;
}
/*----------------------------------------------------------*/

int C_keyquery ()
{
  /* stack: ( a -- b | return true if a key is available ) */

  int result;
  char ch = 0;
  int nread;

  if (key_query_char)
    {
      *GlobalSp-- = -1;
    }
  else
    {
      *GlobalSp-- = 0;
    }

  *GlobalTp-- = OP_IVAL;
  return 0;
}      
/*----------------------------------------------------------*/

int C_accept ()
{
  /* stack: ( a n1 -- n2 | wait for n characters to be received ) */

  char ch, *cp, *cpstart, *bksp = "\010 \010";
  int n1, n2, nr;
//  struct termios t1, t2;

  ++GlobalSp; ++GlobalTp;
  n1 = *GlobalSp++; ++GlobalTp;
  if (*GlobalTp != OP_ADDR) return 1;
  cp = *((char**)GlobalSp);
  cpstart = cp;

  n2 = 0;
  while (n2 < n1)
    {
      nr = read (0, cp, 1);
      if (nr == 1) 
	{
	  if (*cp == 10) 
	    break;
	  else if (*cp == 8)
	    {
	      --cp; --n2;
	      if ((cp < cpstart) || (n2 < 0))
		{ 
		  n2 = 0;
		  cp = cpstart;
		}
	      else
		write (0, bksp, 3);
	    }
	  else
	    {
	      write (0, cp, 1);
	      ++n2; ++cp;
	    }
	}
    }
  *GlobalSp-- = n2;
  *GlobalTp-- = OP_IVAL;
  return 0;
}

/*----------------------------------------------------------*/

int C_numberquery ()
{
  /* stack: ( a -- d b | translate characters into number using current base ) */

  char *token, *pStr, *endp;
  int b, sign;
  unsigned u;

  ++GlobalSp; ++GlobalTp;
  if (GlobalSp > BottomOfStack) return 7; /* stack underflow */
  if (*GlobalTp != OP_ADDR) return 1;     /* VM error: not an address */
  token = *((char**)GlobalSp);
  ++token;
  pStr = token;
  u = 0;
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
	  u = strtoul(token, &endp, Base);
	  b = TRUE;
        }

    }

  *GlobalSp-- = u;
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
  int nc, nr;

  ++GlobalSp; ++GlobalTp;
  if (*GlobalTp != OP_ADDR) return 1;     /* VM error: not an address */
  cp = (char*) (*GlobalSp);
  nc = *cp;
  strncpy (temp_str, cp+1, nc);
  temp_str[nc] = 0;
  nr = WinExec(temp_str, SW_SHOW);
  *GlobalSp-- = nr;
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
