// fbc.h
//
//  Forth Byte Codes (FBC)
//
//  Copyright (c) 1996--2020 Krishna Myneni
//  
//  Provided under the terms of the GNU Affero General Public License
//  (AGPL) v 3.0 or later.
//
#ifndef __FORTHBYTECODES_H__
#define __FORTHBYTECODES_H__

#define OP_FALSE     0
#define OP_TRUE      1
#define OP_CELLS     2
#define OP_CELLPLUS  3
#define OP_DFLOATS   4
#define OP_DFLOATPLUS  5
#define OP_CASE      6
#define OP_ENDCASE   7
#define OP_OF        8
#define OP_ENDOF     9

#define OP_CR       30
#define OP_BL       31
#define OP_CQUOTE   34
#define OP_SQUOTE   29
#define OP_DOTPAREN 23

#define OP_BRACKETSHARP 24
#define OP_SHARP    '#'
#define OP_SHARPBRACKET 27
#define OP_SHARPS   28
#define OP_SIGN     36
#define OP_HOLD     41


#define OP_EMIT     'e'
#define OP_SPACES   ' '
#define OP_COUNT    'c'
#define OP_TYPE     't'
#define OP_LPAREN   '('



#define OP_CHAR     'U'
#define OP_BRACKETCHAR 'V'
#define OP_WORD     'W'
#define OP_CREATE   'r'
#define OP_DOES     'x'
#define OP_FORGET   'G'
#define OP_COLD     'g'
#define OP_VARIABLE 'v'
#define OP_FVARIABLE 'l'
#define OP_CONSTANT  'o'
#define OP_FCONSTANT 'q'

#define OP_SYSTEM   'y'
#define OP_CHDIR    'z'
#define OP_TIMEANDDATE 'm'
#define OP_ALLOT    'a'

#define OP_BASE     'B'
#define OP_BINARY   'b'
#define OP_DECIMAL  'd'
#define OP_HEX      'h'

#define OP_I        'i'
#define OP_J        'j'

#define OP_KEY      'K'
#define OP_KEYQUERY 'Q'
#define OP_ACCEPT   'T'

#define OP_FVAL     'F'
#define OP_IVAL     'I'
#define OP_ADDR     'A'
#define OP_CALL     'C'
#define OP_DEFINITION 'D'

#define OP_QUESTION '?'
#define OP_FETCH    '@'
#define OP_STORE    '!'

#define OP_DOT      '.'
#define OP_DOTR     'O'
#define OP_DDOT     'P'
#define OP_UDOT     'u'
#define OP_UDOTR    'Z'
#define OP_FDOT     'f'
#define OP_DOTQUOTE 's'
#define OP_DOTS     'S'

#define OP_NUMBERQUERY 'N'

// dictionary operations

#define OP_WORDS    'w'
#define OP_FIND     'n'
#define OP_TICK     39
#define OP_BRACKETTICK 'k'

// arithmetic operators

#define OP_ADD      '+'
#define OP_SUB      '-'
#define OP_MUL      '*'
#define OP_DIV      '/'
#define OP_MOD      '%'
#define OP_SLASHMOD 'M'
#define OP_STARSLASH 'X'
#define OP_STARSLASHMOD 'Y'

// bitwise logic and shift operators

#define OP_AND      '&'
#define OP_OR       '|'
#define OP_XOR      '^'
#define OP_NOT      '~'
#define OP_LSHIFT   'L'
#define OP_RSHIFT   'R'


// file access functions

#define OP_OPEN     10
#define OP_LSEEK    11
#define OP_CLOSE    12
#define OP_READ     13
#define OP_WRITE    14
#define OP_IOCTL    15

#define OP_USLEEP   16
#define OP_MS       17
#define OP_MSFETCH  18

// memory

#define OP_FILL     20
#define OP_CMOVE    21
#define OP_CMOVEFROM 22
#define OP_ERASE    'E'

// input/output stream

#define OP_TOFILE   25
#define OP_CONSOLE  26

#define OP_DABS     48
#define OP_DNEGATE  49

// Mixed Length Operators

#define OP_UMSTAR   50
#define OP_UMSLASHMOD 51
#define OP_MSTAR    52
#define OP_MPLUS    53
#define OP_MSLASH   54
#define OP_MSTARSLASH 55
#define OP_FMSLASHMOD 56
#define OP_SMSLASHREM 57

#define OP_TOBODY    72
#define OP_EVALUATE  74

#define OP_LBRACKET  91
#define OP_RBRACKET  93

#define OP_BACKSLASH 92

#define OP_LITERAL   95
#define OP_QUERYALLOT 96

#define OP_IMMEDIATE 112

#define OP_SEARCH    123
#define OP_COMPARE   125

// floating point functions

#define OP_FSIN     128
#define OP_FCOS     129
#define OP_FTAN     130
#define OP_FASIN    131
#define OP_FACOS    132
#define OP_FATAN    133
#define OP_FEXP     134
#define OP_FLN      135
#define OP_FLOG     136
#define OP_FATAN2   137
#define OP_FTRUNC   138
#define OP_FTRUNCTOS 139

#define OP_FMIN     140
#define OP_FMAX     141
#define OP_FLOOR    142
#define OP_FROUND   143

#define OP_DLT      144
#define OP_DZEROEQ  145
#define OP_DEQ      146
#define OP_TWOPUSH  147
#define OP_TWOPOP   148
#define OP_TWORFETCH 149

#define OP_STOD     150
#define OP_STOF     151
#define OP_DTOF     152
#define OP_FROUNDTOS 153
#define OP_FTOD     154
#define OP_DEGTORAD 155
#define OP_RADTODEG 156

#define OP_DPLUS    157
#define OP_DMINUS   158

// increment, decrement, and other integer numeric operators

#define OP_INC      160
#define OP_DEC      161
#define OP_ABS      162
#define OP_NEG      163
#define OP_MIN      164
#define OP_MAX      165
#define OP_TWOSTAR  166
#define OP_TWODIV   167
#define OP_TWOPLUS  168
#define OP_TWOMINUS 169

// more stack to memory

#define OP_CFETCH   170
#define OP_CSTORE   171
#define OP_WFETCH   172
#define OP_WSTORE   173
#define OP_DFFETCH  174
#define OP_DFSTORE  175
#define OP_SFFETCH  176
#define OP_SFSTORE  177
#define OP_SPFETCH  178
#define OP_PLUSSTORE 179

// floating pt arithmetic

#define OP_FADD     180
#define OP_FSUB     181
#define OP_FMUL     182
#define OP_FDIV     183
#define OP_FABS     184
#define OP_FNEG     185
#define OP_FPOW     186
#define OP_FSQRT    187

// floating pt relational

#define OP_FEQ      190
#define OP_FNE      191
#define OP_FLT      192
#define OP_FGT      193
#define OP_FLE      194
#define OP_FGE      195
#define OP_FZEROEQ  196
#define OP_FZEROLT  197
#define OP_FZEROGT  198

// stack operators

#define OP_DROP     200
#define OP_DUP      201
#define OP_SWAP     202
#define OP_OVER     203
#define OP_ROT      204
#define OP_MINUSROT 205
#define OP_NIP      206
#define OP_TUCK     207
#define OP_PICK     208
#define OP_ROLL     209

#define OP_2DROP    210
#define OP_2DUP     211
#define OP_2SWAP    212
#define OP_2OVER    213
#define OP_2ROT     214
#define OP_DEPTH    215
#define OP_QUERYDUP 216

// 217--219 are used below

// return stack operators

#define OP_PUSH     220
#define OP_POP      221
#define OP_PUSHIP   222
#define OP_RFETCH   223
#define OP_RPFETCH  224

// address fetch operator

#define OP_AFETCH   225

// branch and flow control

#define OP_IF       217
#define OP_ELSE     218
#define OP_THEN     219

#define OP_DO       226
#define OP_LEAVE    227
#define OP_QUERYDO  228
#define OP_ABORTQUOTE 229
#define OP_JZ       230
#define OP_JNZ      231
#define OP_JMP      232
#define OP_LOOP     233
#define OP_PLUSLOOP 234
#define OP_UNLOOP   235
#define OP_EXECUTE  236
#define OP_RECURSE  237
#define OP_RET      238
#define OP_ABORT    239
#define OP_QUIT     240

#define OP_BEGIN    250
#define OP_WHILE    251
#define OP_REPEAT   252
#define OP_UNTIL    253
#define OP_AGAIN    254

// relational operators

#define OP_EQ       '='		
#define OP_LT       '<'		
#define OP_GT       '>'	


#define OP_GE       241
#define OP_LE       242
#define OP_NE       243
#define OP_ZEROEQ   244
#define OP_ZERONE   245
#define OP_ZEROLT   246
#define OP_ZEROGT   247

#define OP_ULT      248
#define OP_UGT      249

// 250--254 are used above

#define OP_BYE      255
#endif
