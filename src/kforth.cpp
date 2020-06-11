// kForth.cpp
//
// The kForth environment
//
// Copyright (c) 1998--2003 Krishna Myneni and David P. Wallace, 
//   Creative Consulting for Research and Education
// 
// This software is provided under the terms of the GNU General Public License.
//
//
// Usage from console prompt:
//
//      kforth [name[.4th]] [-D] [-e string]
//
char* version = "1.0.14-2";
char* Rls_Date = "2003-04-18";

#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>
using namespace std;
// using std::istream;
// using std::ostream;
// using std::cout;
// using std::endl;
// using std::istringstream;
// using std::vector;
// extern "C" {
// #include <stdio.h>
// }
#include "fbc.h"
#include "ForthCompiler.h"
#include "ForthVM.h"

extern vector<DictionaryEntry> Dictionary;
extern char* C_ErrorMessages[];

extern "C" int* JumpTable;
extern "C" int* BottomOfStack;
extern "C" int* BottomOfReturnStack;
extern "C" char TIB[];
int debug = 0;

int main(int argc, char *argv[])
{
    char name[256], InFileName[256], OutFileName[256], *cp, ch;
    char s[256], input_line[1024];
    istringstream* pSS = NULL;
    char* prompt = " ok\n";
    vector<byte> op;
    int nWords, i, j, ec;

    if (argc < 2)
      {
	  cout << "\nkForth v " << version << "\t (Rls. " << Rls_Date << ")";
	cout << "\nCopyright (c) 1998--2003 Krishna Myneni and David P. Wallace";
	cout << "\nCreative Consulting for Research and Education";
	cout << "\nProvided under the GNU General Public License.\n\n";
      }

    nWords = OpenForth();

    i = 1;
    *s = 0;

    while (i < argc)
      {
	if (strstr(argv[i], "-D"))
	  {
	    debug = -1;
	  }
	else if (strstr(argv[i], "-e "))
	  {
	    if (argc > i)
	      { 
		strcat (s, argv[i+1]);
		strcat (s, "\n");
	      }
	    ++i;
	  }
	else
	  {
	    strcat (s, "include ");
	    strcat (s, argv[i]);
	    strcat (s, "\n");
	  }
	++i;
      }

    if (*s) pSS = new istringstream(s);

    if (debug) cout << '\n' << nWords << " words defined.\n";

    int* sp;
    byte* tp;
    int line_num = 0;

    if (debug) 
    {
	cout << "Jump Table address:  " << JumpTable << endl;
	cout << "Bottom of Stack:     " << BottomOfStack << endl;
	cout << "Bottom of Ret Stack: " << BottomOfReturnStack << endl;
    }
    if ( ! pSS) cout << "\nReady!\n";

//----------------  the interpreter main loop

    SetForthOutputStream (cout);

    while (1)
    {

        // Obtain commands and execute

        do
        {
	    if (! pSS)
	    {
		// input_line = readline(NULL);
		// if (strlen(input_line)) add_history(input_line);
		cin >> input_line;
		strncpy(s, input_line, 255);
		// free(input_line);
	       
            	pSS = new istringstream(s);
	    }
	    SetForthInputStream (*pSS);	    
            ec = ForthCompiler (&op, &line_num);
	    delete pSS;
	    pSS = NULL;

        } while (ec == E_C_ENDOFSTREAM) ;   // test for premature end of input
                                            //   that spans multiple lines

        if (ec)
        {

	    if (ec < MAX_ERR_MESSAGES)
	      cout << "Line " << line_num << ": " << C_ErrorMessages[ec] << endl;
	    cout << TIB << endl;

        }

	cout << prompt;
        op.erase(op.begin(), op.end());

    }

}
//---------------------------------------------------------------

