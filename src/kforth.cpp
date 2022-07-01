// kForth.cpp
//
// The kForth environment
//
// Copyright (c) 1998--2022 Krishna Myneni, 
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
#ifdef VERSION
const char* version=VERSION;
#else
const char* version="?";
#endif
const char* build="2022-07-01";

#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>
using namespace std;

#include "fbc.h"
#include "ForthCompiler.h"
#include "ForthVM.h"
#include "VMerrors.h"

extern vector<WordList> Dictionary;

extern "C" long int* JumpTable;
extern "C" long int* BottomOfStack;
extern "C" long int* BottomOfReturnStack;
extern "C" char TIB[];
extern "C" {
    void echo_on(void);
    void echo_off(void);
}

bool debug = false;

int main(int argc, char *argv[])
{
    ostringstream initial_commands (ostringstream::out);
    istringstream* pSS = NULL;
    const char* prompt = " ok\n";
    int nWords = OpenForth();

    if (argc < 2) {
	cout << "kForth-Win32 v " << version << "\t (Build: " << build << ")" << endl;
	cout << "Copyright (c) 1998--2022 Krishna Myneni" << endl;
        cout << "Contributions by: dpw gd mu bk abs tn cmb bg dnw" << endl;
	cout << "Provided under the GNU Affero General Public License, v3.0 or later."
		<< endl << endl;
      }
    else {
      int i = 1;

      while (i < argc) {
	if (!strcmp(argv[i], "-D")) {
	    debug = true;
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
    long int line_num = 0, ec = 0;
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
	    cin.getline( input_line, 1024 );
	    if (cin.fail()) CPP_bye();
	    strncpy(s, input_line, 255);

            pSS = new istringstream(s);
	    SetForthInputStream (*pSS);	    
            ec = ForthCompiler (&op, &line_num);
	    delete pSS;
	    pSS = NULL;

        } while (ec == E_V_END_OF_STREAM) ; // test for premature end of input
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

