# kForth-Win32
A 32-bit Forth system for Windows

Development tools required to build the executable, kforth.exe, from source are:

* Digital Mars C/C++ compiler v 8.57
* A386 assembler v 4.05

The A386 assembler is needed to assemble vm.asm to its object file, vm.obj. If you do not want to modify vm.asm then the A386 assembler is not needed -- the preassembled vm.obj is supplied in the src/ folder.

