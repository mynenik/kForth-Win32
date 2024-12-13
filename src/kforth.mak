ORIGIN		= Digital Mars C++
ORIGIN_VER	= Version 8.57
VERSION		= Release

DEBUG		= $(SUB_DEBUG)
NDEBUG		= !$(SUB_DEBUG)

PROJ		= kforth
APPTYPE		= WIN32 CONSOLE
PROJTYPE	= exe

CC		= SC
CPP		= SPP
JAVAC		= sj
MAKE		= SMAKE
RC		= RCC
HC		= HC31
# ASM		= SC
DISASM		= OBJ2ASM
LNK		= LINK
DLLS		= 

HEADERS		= fbc.h \
		  kfmacros.h \
		  ForthWords.h \
		  ForthCompiler.h \
		  ForthVM.h

DEFFILE		= kforth.DEF
DEF_DIR_VAR     = ""

OUTPUTDIR	= .
CREATEOUTPUTDIR	=
TARGETDIR	= .
CREATETARGETDIR =

SYMROOT		= 
SYMS		= 
LIBS		= advapi32.lib KERNEL32.LIB GDI32.LIB USER32.LIB 

CFLAGS		=  -Jm -mn -C -WA -S -3 -a8 -c -w- -w2 -w3 -w6 -g 
LFLAGS		=  /CO /NOI /DE /PACKF /XN /NT /ENTRY:mainCRTStartup /VERS:1.0 /BAS:4194304 /A:512 /RC   :kforth.RES 
DEFINES		= -D_WIN32_ -D__NO_FPSTACK__ -D_CONSOLE -D_CONSOLE=1 -DDIR_ENV_VAR=\"KFORTH_DIR\" -DVERSION=\"2.5.1\"

HFLAGS		= $(CFLAGS) 
MFLAGS		= MASTERPROJ=$(PROJ) 
LIBFLAGS	=  /C /P:512 
RESFLAGS	=  -32 
DEBUGGERFLAGS	=  
AFLAGS		= $(CFLAGS) 
HELPFLAGS	= 

MODEL		= N

PAR		= PROJS BATS OBJS
RCDEFINES	= 
INCLUDES	= -ID:\dm\stlport\stlport
INCLUDEDOBJS	= VM32.OBJ
OBJS		= ForthCompiler.OBJ ForthVM.OBJ vmc.OBJ kforth.OBJ
RCFILES		= kforth.rc
RESFILES	= kforth.RES
HELPFILES	= 
BATS		= 

.SUFFIXES: .C .CP .CPP .CXX .CC .H .HPP .HXX .COM .EXE .DLL .LIB .RTF .DLG .ASM .RES .RC .OBJ 

.C.OBJ:
	$(CC) $(CFLAGS) $(DEFINES) $(INCLUDES) -o$*.obj $*.c
.CPP.OBJ:
	$(CC) $(CFLAGS) $(DEFINES) $(INCLUDES) -o$*.obj $*.cpp
.CXX.OBJ:
	$(CC) $(CFLAGS) $(DEFINES) $(INCLUDES) -o$*.obj $*.cxx
.CC.OBJ:
	$(CC) $(CFLAGS) $(DEFINES) $(INCLUDES) -o$*.obj $*.cc
.CP.OBJ:
	$(CC) $(CFLAGS) $(DEFINES) $(INCLUDES) -o$*.obj $*.cp
.H.SYM:
	$(CC) $(HFLAGS) $(DEFINES) $(INCLUDES) -HF -o$(*B).sym $*.h
.HPP.SYM:
	$(CC) $(HFLAGS) $(DEFINES) $(INCLUDES) -HF -o$(*B).sym $*.hpp
.HXX.SYM:
	$(CC) $(HFLAGS) $(DEFINES) $(INCLUDES) -HF -o$(*B).sym $*.hxx
.C.EXP:
	$(CPP) $(CFLAGS) $(DEFINES) $(INCLUDES)   $*.c   -o$*.lst
.CPP.EXP:
	$(CPP) $(CFLAGS) $(DEFINES) $(INCLUDES) $*.cpp -o$*.lst
.CXX.EXP:
	$(CPP) $(CFLAGS) $(DEFINES) $(INCLUDES) $*.cxx -o$*.lst
.CP.EXP:
	$(CPP) $(CFLAGS) $(DEFINES) $(INCLUDES)  $*.cp  -o$*.lst
.CC.EXP:
	$(CPP) $(CFLAGS) $(DEFINES) $(INCLUDES)  $*.cc  -o$*.lst

# .ASM.EXP:
#	$(CPP) $(CFLAGS) $(DEFINES) $(INCLUDES) $*.asm -o$*.lst

.OBJ.COD:
	$(DISASM) $*.OBJ -c

.OBJ.EXE:
	$(LNK) $(LFLAGS) @<<$(PROJ).LNK
kforth.OBJ+
ForthCompiler.OBJ+
ForthVM.OBJ+
vmc.OBJ+
vm32.OBJ
$$SCW$$.EXE
NUL
advapi32.lib KERNEL32.LIB GDI32.LIB USER32.LIB 
kforth.DEF;
<<

.RTF.HLP:
	$(HC) $(HELPFLAGS) $*.HPJ

# .ASM.OBJ:
#	$(ASM) $(AFLAGS) $(DEFINES) $(INCLUDES) -o$*.obj $*.asm

.RC.RES: 
	$(RC) $(RCDEFINES) $(RESFLAGS) $(INCLUDES) $*.rc -o$*.res


all:	noteout createdir $(PRECOMPILE) $(SYMS) $(OBJS) $(INCLUDEDOBJS) $(POSTCOMPILE) $(TARGETDIR)\$(PROJ).$(PROJTYPE) $(POSTLINK) _done


all2:	createdir $(PRECOMPILE) $(SYMS) $(OBJS) $(INCLUDEDOBJS) $(POSTCOMPILE) $(TARGETDIR)\$(PROJ).$(PROJTYPE) $(POSTLINK) _done

noteout:
	REM Output to $(OUTPUTDIR)

createdir:
	$(CREATEOUTPUTDIR)
	$(CREATETARGETDIR)
	
$(TARGETDIR)\$(PROJ).$(PROJTYPE): $(OBJS) $(INCLUDEDOBJS) $(RCFILES) $(RESFILES) $(HELPFILES) $(DEFFILE)
			-del $(TARGETDIR)\$(PROJ).$(PROJTYPE0)

	$(LNK) $(LFLAGS) @<<$(PROJ).LNK
kforth.OBJ+
ForthCompiler.OBJ+
ForthVM.OBJ+
vmc.OBJ+
vm32.OBJ
$$SCW$$.EXE
NUL
advapi32.lib KERNEL32.LIB GDI32.LIB USER32.LIB 
kforth.DEF;
<<

		-ren $(TARGETDIR)\$$SCW$$.$(PROJTYPE) $(PROJ).$(PROJTYPE)
		-echo $(TARGETDIR)\$(PROJ).$(PROJTYPE) built

_done:
		REM  Project is up to date

buildall:	clean	all


clean:
		-del $(TARGETDIR)\$$SCW$$.$(PROJTYPE)
		-del $(PROJ).CLE
		-del $(OUTPUTDIR)\SCPH.SYM
		-del $(OBJS)
		-del kforth.RES

cleanres:
		-del $(OUTPUTDIR)\kforth.RES

res:		cleanres $(RCFILES) all


link:

	$(LNK) $(LFLAGS) @<<$(PROJ).LNK
kforth.OBJ+
ForthCompiler.OBJ+
ForthVM.OBJ+
vmc.OBJ+
vm32.OBJ
$$SCW$$.EXE
NUL
advapi32.lib KERNEL32.LIB GDI32.LIB USER32.LIB 
kforth.DEF;
<<

		-del $(TARGETDIR)\$(PROJ).$(PROJTYPE)
		-ren $(TARGETDIR)\$$SCW$$.$(PROJTYPE) $(PROJ).$(PROJTYPE)




!IF EXIST (kforth.dpd)
!INCLUDE kforth.dpd
!ENDIF



$(OUTPUTDIR)\kforth.OBJ:	kforth.cpp
		$(CC) $(CFLAGS) $(DEFINES) $(INCLUDES) -o$(OUTPUTDIR)\kforth.obj kforth.cpp



$(OUTPUTDIR)\ForthCompiler.OBJ:	ForthCompiler.cpp
		$(CC) $(CFLAGS) $(DEFINES) $(INCLUDES) -o$(OUTPUTDIR)\ForthCompiler.obj ForthCompiler.cpp



$(OUTPUTDIR)\ForthVM.OBJ:	ForthVM.cpp
		$(CC) $(CFLAGS) $(DEFINES) $(INCLUDES) -o$(OUTPUTDIR)\ForthVM.obj ForthVM.cpp



$(OUTPUTDIR)\vmc.OBJ:	vmc.c
		$(CC) $(CFLAGS) $(DEFINES) $(INCLUDES) -o$(OUTPUTDIR)\vmc.obj vmc.c


