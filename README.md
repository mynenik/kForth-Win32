# kForth-Win32
A 32-bit Forth system for Windows

## System Requirements

OS: Windows 10

A prebuilt executable, kforth.exe, is provided in the bin/ folder. The executable may also be run on GNU/Linux x86/x86_64 systems with recent versions of the Windows emulator, Wine.

Development tools required to build the executable from source are:

* Digital Mars C/C++ compiler v 8.57
* A386 assembler v 4.05

The A386 assembler is needed to assemble vm.asm to its object file, vm.obj. If you do not want to modify vm.asm then the A386 assembler is not needed -- the preassembled vm.obj is supplied in the src/ folder.

## Installation Instructions

1. Download the ZIP file for the master or release version you want. The master will contain the most recent features, but a release version will usually be more stable.

2. Extract the files from the ZIP file. They will extract into a separate folder, such as kForth-Win32-master.

3. The executabe, kforth.exe, is found in the sub-folder, bin/. Create a shortcut for the executable and drag the shortcut onto your desktop for easy access.

4. The exe file must be able to find its Forth source files, which are located in the subfolder, forth-src/ of the extracted files. Create an environment variable, KFORTH_DIR, to specify the location of the Forth source files (.4th). Follow the steps below to set the environment variable.

5. Go to the Windows toolbar search field and type, "env". Then, select "Edit the environment variables for your account."

6. Under "User Variables for [your account name]", click on "New". Then, set the variable name to KFORTH_DIR and the variable value to the full path specifying the location of the forth-src folder, e.g. C:\Users\John\kForth-Win32-1.7.1\forth-src . Click "OK".

7. When you launch kForth from its desktop shortcut, it will open up a console and start the Forth environment.

8. Follow the User's Guide, found in the doc/ subfolder of the package, to learn how to interact with the Forth environment to perform computations, write words, or load Forth programs from text files.

9. Some programs assume that the console emulates an ANSI VT terminal. To ensure that Windows consoles perform virtual terminal emulation, check/edit the Windows registry, to set VirtualTerminalLevel as described in the next step.

10. Go to the Windows toolbar search field and type, "reg". Then, click on the Registry Editor app. Right-click on "Console" under HKEY_CURRENT_USER and select "New DWORD 32-bit value". Edit the name of the new value to "VirtualTerminalLevel" and press Enter. Right-click on "VirtualTerminalLevel" and select "Modify" and set the value data to 1. Click ok. You will have to restart before the new value takes effect. Afterwards, the console will respond correctly to ANSI terminal control sequences.

 
