// kForth.cpp
//
// The kForth environment
//
// Copyright (c) 1998--2020 Krishna Myneni and David P. Wallace, 
//   <krishna.myneni@ccreweb.org>
//
// This software is provided under the terms of the GNU 
// Affero General Public License (AGPL), v 3.0 or later.
//
// Contributions by (source code, bug fixes, documentation, 
// packaging, misc):
//
//    David P. Wallace          input line history, default directory,
//                                cygwin port, misc.
//    Matthias Urlichs          maintains Debian package
//    Guido Draheim             maintains RPM packages
//    Brad Knotwell             interpreter Ctrl-D handling and dictionary
//                                initialization.
//    Alaric B. Snell           command line parsing
//    Todd Nathan               ported kForth to BeOS
//    Bdale Garbee              created Debian kForth package
//    Christopher M. Brannon    bug alert for default-directory handling
//    David N. Williams         Mac OS X ppc engine port, a few new words
//
// Usage from console prompt:
//
//      kforth [name[.4th]] [-D] [-e string]
//
char* version = "1.0.16";
char* Rls_Date = "2020-06-22";

#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>
using namespace std;
#include "fbc.h"
#include "ForthCompiler.h"
#include "ForthVM.h"

extern vector<DictionaryEntry> Dictionary;

extern "C" int* JumpTable;
extern "C" int* BottomOfStack;
extern "C" int* BottomOfReturnStack;
extern "C" char TIB[];
int debug = 0;

int main(int argc, char *argv[])
{
    char name[256], InFileName[256], OutFileName[256], *cp, ch;
    ostringstream initial_commands (ostringstream::out);
    istringstream* pSS = NULL;
    char* prompt = " ok\n";
    int nWords = OpenForth();

    if (argc < 2) {
	cout << "kForth-Win32 v " << version << "\t (Rls. " << Rls_Date << ")" << endl;
	cout << "Copyright (c) 1998--2020 Krishna Myneni" << endl;
        cout << "Contributions by: dpw gd mu bk abs tn cmb bg dnw" << endl;
	cout << "Provided under the GNU Affero General Public License, v3.0 or later."
		<< endl << endl;
      }
    else {
      int i = 1;

      while (i < argc) {
	if (!strcmp(argv[i], "-D")) {
	    debug = -1;
	  }
	else if (!strcmp(argv[i], "-e ")) {
	  if (argc > i) { 
	    initial_commands << argv[i+1] << endl;
	  }
	  ++i;
	}
	else {
	  initial_commands << "include " << argv[i] << endl;
	}
	++i;
      }
      pSS = new istringstream(initial_commands.str());
    }
    if (debug) {
       cout << '\n' << nWords << " words defined." << endl;
       cout << "Jump Table address:  " << &JumpTable << endl;
       cout << "Bottom of Stack:     " << BottomOfStack << endl;
       cout << "Bottom of Ret Stack: " << BottomOfReturnStack << endl;
    }

    SetForthOutputStream(cout);
    int line_num = 0, ec = 0;
    vector<byte> op;

    if (pSS) {
      SetForthInputStream(*pSS);
      ec = ForthCompiler(&op, &line_num);
      if (ec) {
        PrintVM_Error(ec); exit(ec);
      }
      delete pSS; pSS = NULL;
      op.erase(op.begin(), op.end());
      cout << prompt;
    }
    else
      cout << "\nReady!\n";

//----------------  the interpreter main loop

    char s[256], input_line[1024];

    while (1) {
        // Obtain commands and execute
        do {
	    if (! pSS)
	    {
		cin.getline( input_line, 1024 );
            	pSS = new istringstream(input_line);
	    }
	    SetForthInputStream (*pSS);	    
            ec = ForthCompiler (&op, &line_num);
	    delete pSS;
	    pSS = NULL;

        } while (ec == E_C_ENDOFSTREAM) ;   // test for premature end of input
                                            //   that spans multiple lines
        if (ec) {
	    cout << "Line " << line_num << ": "; PrintVM_Error(ec);
	    cout << TIB << endl;
        }
	else
	  cout << prompt;
        op.erase(op.begin(), op.end());
    }
}

