; vm32.asm
;
; The assembler portion of kForth 32-bit Virtual Machine
;
; Copyright (c) 1998--2022 Krishna Myneni
;
; This software is provided under the terms of the GNU
;   Affero General Public License (AGPL) v 3.0 or later.
;
; Usage from C++
;
;       extern "C" int vm (byte* ip);
;       ecode = vm(ip);
;
; Written for the A386 assembler
;
;       a386 +c+O vm32.asm
;
        .386p

public _GlobalSp, _GlobalTp, _GlobalIp, _GlobalRp, _GlobalRtp
public _BottomOfStack, _BottomOfReturnStack, _BottomOfTypeStack
public _BottomOfReturnTypeStack, _vmEntryRp, _Base, _State
public _Precision, _pTIB, _TIB, _WordBuf
public _NumberCount, _NumberBuf, _JumpTable

EXTRN _Sleep@4:NEAR

WSIZE   equ 4

OP_ADDR equ 65
OP_FVAL equ 70
OP_IVAL equ 73
OP_RET  equ 238
SIGN_MASK  equ  080000000H

; Error Codes must be same as those in VMerrors.h

E_DIV_ZERO      equ     -10
E_ARG_TYPE_MISMATCH equ -12
E_QUIT          equ     -56
E_NOT_ADDR      equ     -256
E_RET_STK_CORRUPT equ   -258
E_BAD_OPCODE    equ     -259
E_DIV_OVERFLOW  equ     -270

_DATA SEGMENT PUBLIC FLAT
NDPcw      dd 0
FCONST_180 dq 180.
_GlobalSp dd 0
_GlobalTp dd 0
_GlobalIp dd 0
_GlobalRp dd 0
_GlobalRtp dd 0
_BottomOfStack dd 0
_BottomOfReturnStack dd 0
_BottomOfTypeStack dd 0
_BottomOfReturnTypeStack dd 0
_vmEntryRp dd 0
_Base dd 0
_State dd 0
_Precision dd 0
_pTIB dd 0
_TIB db 256 dup 0
_WordBuf db 256 dup 0
_NumberCount dd 0
_NumberBuf db 256 dup 0

_JumpTable dd L_false, L_true, L_cells, L_cellplus ; 0 -- 3
          dd L_dfloats, L_dfloatplus, _CPP_case, _CPP_endcase ; 4 -- 7
          dd _CPP_of, _CPP_endof, _C_open, _C_lseek   ; 8 -- 11
          dd _C_close, _C_read, _C_write, _C_ioctl ; 12 -- 15
          dd L_usleep, L_ms, _C_msfetch, L_nop     ; 16 -- 19
          dd L_fill, L_cmove, L_cmovefrom, _CPP_dotparen  ; 20 -- 23
          dd _C_bracketsharp, L_nop, _C_fsync, _C_sharpbracket   ; 24 -- 27
          dd _C_sharps, _CPP_squote, _CPP_cr, L_bl      ; 28 -- 31
          dd _CPP_spaces, L_store, _CPP_cquote, _C_sharp ; 32 -- 35
          dd _C_sign, L_mod, L_and, _CPP_tick      ; 36 -- 39
          dd _CPP_lparen, _C_hold, L_mul, L_add    ; 40 -- 43
          dd L_nop, L_sub, _CPP_dot, L_div     ; 44 -- 47
          dd _L_dabs, _L_dnegate, L_umstar, L_umslashmod   ; 48 -- 51
          dd L_mstar, L_mplus, L_mslash, _L_mstarslash ; 52 -- 55
          dd L_fmslashmod, L_smslashrem, _CPP_colon, _CPP_semicolon ; 56 -- 59
          dd L_lt, L_eq, L_gt, L_question      ; 60 -- 63
          dd L_fetch, L_addr, L_base, L_call   ; 64 -- 67
          dd L_definition, L_erase, L_fval, L_calladdr ; 68 -- 71
          dd L_tobody, L_ival, _CPP_evaluate, _C_key   ; 72 -- 75
          dd L_lshift, L_slashmod, L_ptr, _CPP_dotr   ; 76 -- 79
          dd _CPP_ddot, _C_keyquery, L_rshift, _CPP_dots ; 80 -- 83
          dd _C_accept, _CPP_char, _CPP_bracketchar, _C_word    ; 84 -- 87
          dd L_starslash, L_starslashmod, _CPP_udotr, _CPP_lbracket   ; 88 -- 91
          dd L_backslash, _CPP_rbracket, L_xor, _CPP_literal  ; 92 -- 95
          dd _CPP_queryallot, _CPP_allot, L_binary, L_count ; 96 -- 99
          dd L_decimal, _CPP_emit, _CPP_fdot, _CPP_cold   ; 100 -- 103
          dd L_hex, L_i, L_j, _CPP_brackettick ; 104 -- 107
          dd _CPP_fvariable, L_2store, _CPP_find, _CPP_constant  ; 108 -- 111
          dd _CPP_immediate, _CPP_fconstant, _CPP_create, _CPP_dotquote ; 112 -- 115
          dd _CPP_type, _CPP_udot, _CPP_variable, _CPP_words ; 116 -- 119
          dd _CPP_does, L_2val, L_2fetch, _C_search ; 120 -- 123
          dd L_or, _C_compare, L_not, L_move   ; 124 -- 127
          dd L_fsin, L_fcos, _C_ftan, _C_fasin ; 128 -- 131
          dd _C_facos, _C_fatan, _C_fexp, _C_fln   ; 132 -- 135
          dd _C_flog, L_fatan2, L_ftrunc, L_ftrunctos   ; 136 -- 139
          dd _C_fmin, _C_fmax, L_floor, L_fround ; 140 -- 143
          dd L_dlt, L_dzeroeq, L_deq, L_twopush_r  ; 144 -- 147
          dd L_twopop_r, L_tworfetch, L_stod, L_stof   ; 148 -- 151
          dd L_dtof, L_froundtos, L_ftod, L_degtorad ; 152 -- 155
          dd L_radtodeg, _L_dplus, _L_dminus, L_dult ; 156 -- 159
          dd L_inc, L_dec, L_abs, L_neg        ; 160 -- 163
          dd L_min, L_max, L_twostar, L_twodiv ; 164 -- 167
          dd L_twoplus, L_twominus, L_cfetch, L_cstore ; 168 -- 171
          dd L_swfetch, L_wstore, L_dffetch, L_dfstore  ; 172 -- 175
          dd L_sffetch, L_sfstore, L_spfetch, L_plusstore ; 176 -- 179
          dd L_fadd, L_fsub, L_fmul, L_fdiv    ; 180 -- 183
          dd L_fabs, L_fneg, _C_fpow, L_fsqrt   ; 184 -- 187
          dd _CPP_spstore, _CPP_rpstore, L_feq, L_fne ; 188 -- 191
          dd L_flt, L_fgt, L_fle, L_fge        ; 192 -- 195
          dd L_fzeroeq, L_fzerolt, L_fzerogt, L_nop ; 196 -- 199
          dd L_drop, L_dup, L_swap, L_over     ; 200 -- 203
          dd L_rot, L_minusrot, L_nip, L_tuck  ; 204 -- 207
          dd L_pick, L_roll, L_2drop, L_2dup   ; 208 -- 211
          dd L_2swap, L_2over, L_2rot, _L_depth ; 212 -- 215
          dd L_querydup, _CPP_if, _CPP_else, _CPP_then ; 216 -- 219
          dd L_push_r, L_pop_r, L_puship, L_rfetch ; 220 -- 223
          dd L_rpfetch, L_afetch, _CPP_do, _CPP_leave ; 224 -- 227
          dd _CPP_querydo, _CPP_abortquote, L_jz, L_jnz ; 228 -- 231
          dd L_jmp, L_rtloop, L_rtplusloop, L_rtunloop ; 232 -- 235
          dd L_execute, _CPP_recurse, _L_ret, _L_abort  ; 236 -- 239
          dd _L_quit, L_ge, L_le, L_ne         ; 240 -- 243
          dd L_zeroeq, L_zerone, L_zerolt, L_zerogt ; 244 -- 247
          dd L_ult, L_ugt, _CPP_begin, _CPP_while ; 248 -- 251
          dd _CPP_repeat, _CPP_until, _CPP_again, _CPP_bye ; 252 -- 255
          dd _L_utmslash, L_utsslashmod, L_stsslashrem, _L_udmstar ; 256 -- 259
          dd _CPP_included, _CPP_include, _CPP_source, _CPP_refill ; 260 -- 263
          dd _CPP_state, _CPP_allocate, _CPP_free, _CPP_resize ; 264 -- 267
          dd L_cputest, L_dsstar, _CPP_compilecomma, L_nop  ; 268 -- 271
          dd _CPP_postpone, _CPP_nondeferred, _CPP_forget, L_nop ; 272 -- 275
          dd L_nop, L_nop, L_nop, L_nop ; 276 -- 279
          dd _C_tofloat, L_fsincos, _C_facosh, _C_fasinh ; 280 -- 283
          dd _C_fatanh, _C_fcosh, _C_fsinh, _C_ftanh ; 284 -- 287
          dd _C_falog, L_dzerolt, L_dmax, L_dmin  ; 288 -- 291
          dd L_dtwostar, L_dtwodiv, _CPP_uddot, L_within  ; 292 -- 295
          dd _CPP_twoliteral, _C_tonumber, _C_numberquery, _CPP_sliteral ; 296 -- 299
          dd _CPP_fliteral, _CPP_twovariable, _CPP_twoconstant, L_nop ; 300 -- 303
          dd _CPP_tofile, _CPP_console, _CPP_loop, _CPP_plusloop  ; 304 -- 307
          dd _CPP_unloop, _CPP_noname, L_nop, L_blank  ; 308 -- 311
          dd L_slashstring, _C_trailing, _C_parse, L_nop ; 312 -- 315
          dd L_nop, L_nop, L_nop, L_nop  ; 316 -- 319
          dd _C_dlopen, _C_dlerror, _C_dlsym, _C_dlclose  ; 320 -- 323
          dd L_nop, _CPP_alias, _C_system, _C_chdir ; 324 -- 327
          dd _C_timeanddate, L_nop, _CPP_wordlist, _CPP_forthwordlist ; 328 -- 331
          dd _CPP_getcurrent, _CPP_setcurrent, _CPP_getorder, _CPP_setorder ; 332 -- 335
          dd _CPP_searchwordlist, _CPP_definitions, _CPP_vocabulary, L_nop ; 336 -- 339
          dd _CPP_only, _CPP_also, _CPP_order, _CPP_previous ; 340 -- 343
          dd _CPP_forth, _CPP_assembler, L_nop, L_nop ; 344 -- 347
          dd L_nop, L_nop, _CPP_defined, _CPP_undefined ; 348 -- 351
          dd L_nop, L_nop, L_nop, L_nop      ; 352 -- 355
          dd L_nop, L_nop, L_nop, L_vmthrow  ; 356 -- 359
          dd L_precision, L_setprecision, L_nop, _CPP_fsdot ; 360 -- 363
          dd L_nop, L_nop, _C_fexpm1, _C_flnp1  ; 364 -- 367
          dd _CPP_uddotr, _CPP_ddotr, L_f2drop, L_f2dup  ; 368 -- 371
          dd L_nop, L_nop, L_nop, L_nop  ; 372 -- 375
          dd L_nop, L_nop, L_nop, L_nop  ; 376 -- 379  
          dd L_nop, L_nop, L_nop, L_nop  ; 380 -- 383
          dd L_nop, L_nop, L_nop, L_nop  ; 384 -- 387
          dd L_nop, L_nop, L_nop, L_nop  ; 388 -- 391
          dd L_nop, L_nop, L_nop, L_nop  ; 392 -- 395
          dd L_nop, L_nop, L_nop, L_nop  ; 396 -- 399
          dd L_nop, L_nop, L_nop, L_nop  ; 400 -- 403
          dd L_nop, L_uwfetch, L_ulfetch, L_slfetch ; 404 -- 407
          dd L_lstore, L_nop, L_nop, L_nop ; 408 -- 411
          dd L_nop, L_nop, L_nop, L_nop  ; 412 -- 415
          dd L_nop, L_nop, L_nop, L_nop  ; 416 -- 419
          dd L_nop, L_nop, L_nop, L_nop  ; 420 -- 423
          dd L_nop, L_nop, L_nop, L_nop  ; 424 -- 427
          dd L_nop, L_nop, L_nop, L_nop  ; 428 -- 431
          dd L_nop, L_nop, L_nop, L_nop  ; 432 -- 435
          dd L_nop, L_nop, L_nop, L_nop  ; 436 -- 439
          dd L_nop, L_nop, L_nop, L_nop  ; 440 -- 443
          dd L_nop, L_nop, L_nop, L_nop  ; 444 -- 447
          dd L_nop, L_nop, _C_valloc, _C_vfree  ; 448 -- 451
          dd _C_vprotect, L_nop, L_nop, L_nop   ; 452 -- 455
_DATA ENDS

public _L_initfpu, _L_depth, _L_quit, _L_abort, _L_ret
public _L_dabs, _L_dplus, _L_dminus, _L_dnegate
public _L_mstarslash, _L_udmstar, _L_utmslash

public _vm

_TEXT   SEGMENT PUBLIC  FLAT

LDSP     MACRO  mov ebx, _GlobalSp  #EM
STSP     MACRO  mov _GlobalSp, ebx  #EM
INC_DSP  MACRO  add ebx, WSIZE      #EM
DEC_DSP  MACRO  sub ebx, WSIZE      #EM
INC2_DSP MACRO  add ebx, 2*WSIZE    #EM
INC_DTSP MACRO  inc _GlobalTp       #EM
DEC_DTSP MACRO  dec _GlobalTp       #EM
INC2_DTSP MACRO add _GlobalTp, 2    #EM
_NOT     MACRO  not [ebx + WSIZE]   #EM


STD_IVAL MACRO
	mov edx, _GlobalTp
	mov B[edx], OP_IVAL
	dec _GlobalTp
#EM

STD_ADDR MACRO
	mov edx, _GlobalTp
	mov B[edx], OP_ADDR
	dec _GlobalTp
#EM

UNLOOP MACRO
	add _GlobalRp, 3*WSIZE
	add _GlobalRtp, 3
#EM

NEXT MACRO        ; eax reg assumed to be zero
	inc ebp   ; increment the Forth instruction ptr
	mov _GlobalIp, ebp
	mov al, [ebp]    ; get next opcode
	shl eax, 2
	mov ecx, offset _JumpTable
	add ecx, eax
	xor eax, eax
	jmp [ecx]  ; jump to next word
#EM

_DROP MACRO
	INC_DSP
	STSP
	INC_DTSP
#EM

_DUP MACRO        ; assume DSP in ebx reg
	mov ecx, [ebx + WSIZE]
	mov [ebx], ecx
	DEC_DSP
	STSP
	mov ecx, _GlobalTp
	mov al, [ecx + 1]
	mov B[ecx], al
	xor eax, eax
	DEC_DTSP
#EM

_SWAP MACRO
        LDSP
        INC_DSP
        mov eax, [ebx]
	INC_DSP
	mov ecx, [ebx]
	mov [ebx], eax
	mov [ebx - WSIZE], ecx
        mov ebx, _GlobalTp
        inc ebx
        mov al, [ebx]
        inc ebx
	mov cl, [ebx]
        mov B[ebx], al
	mov B[ebx-1], cl
        xor eax, eax
#EM

_OVER MACRO
        LDSP
        mov eax, [ebx + 2*WSIZE]
        mov [ebx], eax
        DEC_DSP
        STSP
        mov ebx, _GlobalTp
        mov al, B[ebx + 2]
        mov B[ebx], al
        dec _GlobalTp
        xor eax, eax
#EM

PUSH_R MACRO
        LDSP
        mov eax, WSIZE
        add ebx, eax
        STSP
        mov ecx, [ebx]
        mov ebx, _GlobalRp
        mov [ebx], ecx
        sub ebx, eax
        mov _GlobalRp, ebx
        mov ebx, _GlobalTp
        inc ebx
        mov _GlobalTp, ebx
        mov al, [ebx]
        mov ebx, _GlobalRtp
        mov B[ebx], al
        dec ebx
        mov _GlobalRtp, ebx
        xor eax, eax
#EM

POP_R MACRO
        mov eax, WSIZE
        mov ebx, _GlobalRp
        add ebx, eax
        mov _GlobalRp, ebx
        mov ecx, [ebx]
        LDSP
        mov [ebx], ecx
        sub ebx, eax
        STSP
        mov ebx, _GlobalRtp
        inc ebx
        mov _GlobalRtp, ebx
        mov al, [ebx]
        mov ebx, _GlobalTp
        mov B[ebx], al
        dec ebx
        mov _GlobalTp, ebx
        xor eax, eax
#EM

FDUP MACRO
        LDSP
        mov ecx, ebx
        INC_DSP
        mov edx, [ebx]
        INC_DSP
        mov eax, [ebx]
        mov ebx, ecx
        mov [ebx], eax
        DEC_DSP
        mov [ebx], edx
        DEC_DSP
        STSP
        mov ebx, _GlobalTp
        inc ebx
        mov ax, W[ebx]
        sub ebx, 2
        mov W[ebx], ax
        dec ebx
        mov _GlobalTp, ebx
        xor eax, eax
#EM

FDROP MACRO
        add _GlobalSp, 2*WSIZE
        INC2_DTSP
        xor eax, eax
#EM

FSWAP MACRO
        LDSP
        mov ecx, WSIZE
        add ebx, ecx
        mov edx, [ebx]
        add ebx, ecx
        mov eax, [ebx]
        add ebx, ecx
        xchg [ebx], edx
        add ebx, ecx
        xchg [ebx], eax
        sub ebx, ecx
        sub ebx, ecx
        mov [ebx], eax
        sub ebx, ecx
        mov [ebx], edx
        mov ebx, _GlobalTp
        inc ebx
        mov ax, W[ebx]
        add ebx, 2
        xchg W[ebx], ax
        sub ebx, 2
        mov W[ebx], ax
        xor eax, eax
#EM

FOVER MACRO
        LDSP
        mov ecx, ebx
        add ebx, 3*WSIZE
        mov edx, [ebx]
        INC_DSP
        mov eax, [ebx]
        mov ebx, ecx
        mov [ebx], eax
        DEC_DSP
        mov [ebx], edx
        DEC_DSP
        STSP
        mov ebx, _GlobalTp
        mov ecx, ebx
        add ebx, 3
        mov ax, W[ebx]
        mov ebx, ecx
        dec ebx
        mov W[ebx], ax
        dec ebx
        mov _GlobalTp, ebx
        xor eax, eax
#EM


; use algorithm from DNW's vm-osxppc.s
_ABS MACRO
	LDSP
	INC_DSP
	mov ecx, [ebx]
	xor eax, eax
	cmp ecx, eax
	setl al
	neg eax
	mov edx, eax
	xor edx, ecx
	sub edx, eax
	mov [ebx], edx
	xor eax, eax
#EM

; Dyadic relational operators (single length numbers)

REL_DYADIC MACRO
        LDSP
        mov ecx, WSIZE
        add ebx, ecx
        STSP
        mov eax, [ebx]
        add ebx, ecx
        cmp [ebx], eax
        mov eax, 0
        #1 al
        neg eax
        mov [ebx], eax
        mov eax, _GlobalTp
        inc eax
        mov _GlobalTp, eax
        mov B[eax + 1], OP_IVAL
        xor eax, eax
#EM

; Relational operators for zero (single length numbers)

REL_ZERO MACRO
        LDSP
        INC_DSP
        mov eax, [ebx]
        cmp eax, 0
        mov eax, 0
        #1 al
        neg eax
        mov [ebx], eax
        mov eax, _GlobalTp
        mov B[eax + 1], OP_IVAL
        xor eax, eax
#EM

FREL_DYADIC MACRO
        LDSP
        mov ecx, WSIZE
        add ebx, ecx
        FLD Q[ebx]
        add ebx, ecx
        add ebx, ecx
        STSP
        FCOMP Q[ebx]
        FNSTSW ax
        and ah, 65
        #1 ah, #2
        mov eax, 0
        #3 al
        neg eax
        add ebx, ecx
        mov [ebx], eax
        mov eax, _GlobalTp
        add eax, 3
        mov _GlobalTp, eax
        mov B[eax + 1], OP_IVAL
        xor eax, eax
#EM

        ; b = (d1.hi < d2.hi) OR ((d1.hi = d2.hi) AND (d1.lo u< d2.lo))
DLT MACRO
        LDSP
        mov ecx, WSIZE
        xor edx, edx
        add ebx, ecx
        mov eax, [ebx]
        cmp [ebx + 2*WSIZE], eax
        sete dl
        setl dh
        add  ebx, ecx
        mov eax, [ebx]
        add ebx, ecx
        STSP
        add ebx, ecx
        cmp [ebx], eax
        setb al
        and dl, al
        or  dl, dh
        xor eax, eax
        mov al, dl
        neg eax
        mov [ebx], eax
        mov eax, _GlobalTp
        add eax, 4
        mov B[eax], OP_IVAL
        dec eax
        mov _GlobalTp, eax
        xor eax, eax
#EM

        ; b = (d1.hi > d2.hi) OR ((d1.hi = d2.hi) AND (d1.lo u> d2.lo))
DGT MACRO
        LDSP
        mov ecx, WSIZE
        xor edx, edx
        add ebx, ecx
        mov eax, [ebx]
        cmp [ebx + 2*WSIZE], eax
        sete dl
        setl dh
        add ebx, ecx
        mov eax, [ebx]
        add ebx, ecx
        STSP
        add ebx, ecx
        cmp [ebx], eax
        setb al
        and dl, al
        or  dl, dh
        xor eax, eax
        mov al, dl
        neg eax
        mov [ebx], eax
        mov eax, _GlobalTp
        add eax, 4
        mov B[eax], OP_IVAL
        dec eax
        mov _GlobalTp, eax
        xor eax, eax
#EM     

STOD MACRO
	LDSP
	mov ecx, WSIZE
	mov eax, [ebx + WSIZE]
	cdq
	mov [ebx], edx
	sub ebx, ecx
	STSP
	STD_IVAL
	xor eax, eax
#EM

DNEGATE MACRO
	LDSP
	INC_DSP
	mov ecx, ebx
	INC_DSP
	mov eax, [ebx]
	not eax
	clc
	add eax, 1
	mov [ebx], eax
	mov ebx, ecx
	mov eax, [ebx]
	not eax
	adc eax, 0
	mov [ebx], eax
	xor eax, eax
#EM

DPLUS MACRO
	LDSP
	INC2_DSP
	mov eax, [ebx]
	clc
	add eax, [ebx + 2*WSIZE]
	mov [ebx + 2*WSIZE], eax
	mov eax, [ebx + WSIZE]
	adc eax, [ebx - WSIZE]
	mov [ebx + WSIZE], eax
	STSP
	INC2_DTSP
	xor eax, eax
#EM

DMINUS MACRO
	LDSP
	INC2_DSP
	mov eax, [ebx + 2*WSIZE]
	clc
	sub eax, [ebx]
	mov [ebx + 2*WSIZE], eax
	mov eax, [ebx + WSIZE]
	sbb eax, [ebx - WSIZE]
	mov [ebx + WSIZE], eax
	STSP
	INC2_DTSP
	xor eax, eax
#EM

STARSLASH MACRO
        mov eax, 2*WSIZE
        add _GlobalSp, eax
        LDSP
        mov eax, [ebx + WSIZE]
        imul [ebx]
        idiv [ebx - WSIZE]
        mov [ebx + WSIZE], eax
        INC2_DTSP
        xor eax, eax
#EM

TNEG MACRO
        LDSP
        mov eax, WSIZE
        add ebx, eax
        mov edx, [ebx]
        add ebx, eax
        mov ecx, [ebx]
        add ebx, eax
        mov eax, [ebx]
        not eax
        not ecx
        not edx
        clc
        add eax, 1
        adc ecx, 0
        adc edx, 0
        mov [ebx], eax
        mov eax, WSIZE
        sub ebx, eax
        mov [ebx], ecx
        sub ebx, eax
        mov [ebx], edx
        xor eax, eax
#EM

; Error jumps
E_not_addr:
        mov eax, E_NOT_ADDR
        ret

E_ret_stk_corrupt:
        mov eax, E_RET_STK_CORRUPT
        ret

E_div_zero:
        mov eax, E_DIV_ZERO
        ret

E_div_overflow:
        mov eax, E_DIV_OVERFLOW
        ret

L_vmthrow:  ; throw VM error (used as default exception handler)
        LDSP
        INC_DSP
        INC_DTSP
        mov eax, [ebx]
        STSP
        ret

L_cputest:
        ret

; set kForth's default fpu settings
_L_initfpu:
	push ebx  ; Win32 stdcall calling convention
        LDSP
        fnstcw offset NDPcw
        mov ecx, NDPcw
        and ch, 240
        or  ch, 2
        mov [ebx], ecx
        fldcw [ebx]
	pop ebx
        ret

_vm     proc    near
;
        push ebp
        push ebx
        push ecx
        push edx
	push _GlobalIp
	push _vmEntryRp
        mov ebp, esp
        mov ebp, [ebp+28]      ; load the Forth instruction pointer
        mov _GlobalIp, ebp
	mov eax, _GlobalRp
	mov _vmEntryRp, eax
	xor eax, eax
next:
        mov al, [ebp]		  ; get the opcode
        shl eax, 2              ; determine offset of opcode
        mov ebx, offset _JumpTable
        add ebx, eax            ; address of machine code
        xor eax, eax            ; clear error code
        call [ebx]              ; call the word
	mov ebp, _GlobalIp      ; resync ip (possibly changed in call)
	inc ebp			; increment the Forth instruction ptr
	mov _GlobalIp, ebp
        cmp eax, 0              ; check for error
        jz next                 ;
exitloop:
        cmp eax, OP_RET         ; return from vm?
        jnz vmexit
        xor eax, eax            ; clear the error
vmexit:
	pop _vmEntryRp
	pop _GlobalIp 
	pop edx
        pop ecx
        pop ebx
        pop ebp
        ret
L_nop:
        mov eax, E_BAD_OPCODE   ; unknown operation
        ret
_L_quit:
        mov eax, _BottomOfReturnStack   ; clear the return stacks
        mov _GlobalRp, eax
	mov _vmEntryRp, eax
        mov eax, _BottomOfReturnTypeStack
        mov _GlobalRtp, eax
        mov eax, E_QUIT              ; exit the virtual machine
        ret
_L_abort:
        mov eax, _BottomOfStack
        mov _GlobalSp, eax
        mov eax, _BottomOfTypeStack
        mov _GlobalTp, eax
        jmp _L_quit
L_base:
        mov ebx, _GlobalSp
        mov eax, offset _Base
        mov [ebx], eax
        sub ebx, WSIZE
        mov _GlobalSp, ebx
        mov ebx, _GlobalTp
        mov B[ebx], OP_ADDR
        dec _GlobalTp
        xor eax, eax
        ret
L_binary:
        mov _Base, 2
        ret
L_decimal:
        mov _Base, 10
        ret
L_hex:
        mov _Base, 16
        ret

L_precision:
        LDSP
        mov ecx, _Precision
        mov [ebx], ecx
        DEC_DSP
        STSP
        STD_IVAL
        NEXT

L_setprecision:
        LDSP
        _DROP
        mov ecx, [ebx]
        mov _Precision, ecx
        NEXT

L_false:
        LDSP
        mov D[ebx], 0
        DEC_DSP
        STSP
        STD_IVAL
        NEXT

L_true:
        LDSP
        mov D[ebx], -1
        DEC_DSP
        STSP
        STD_IVAL
        NEXT

L_cells:
        LDSP
        INC_DSP
        mov eax, [ebx]
        sal eax, 2
        mov [ebx], eax
        xor eax, eax
        NEXT

L_cellplus:
        LDSP
        INC_DSP
        mov eax, [ebx]
        add eax, WSIZE
        mov [ebx], eax
        xor eax, eax
        NEXT

L_dfloats:
        LDSP
        INC_DSP
        mov eax, [ebx]
        sal eax, 3
        mov [ebx], eax
        xor eax, eax
        NEXT

L_dfloatplus:
        LDSP
        INC_DSP
        mov eax, [ebx]
        add eax, WSIZE
        add eax, WSIZE
        mov [ebx], eax
        xor eax, eax
        NEXT

L_bl:
        LDSP
        mov D[ebx], 32
        DEC_DSP
        STSP
        STD_IVAL
        NEXT

_L_ret:
	mov eax, _vmEntryRp	; Return Stack Ptr on entry to VM
	mov ecx, _GlobalRp
	cmp ecx, eax
	jl ret1
	mov eax, OP_RET		; exhausted the return stack so exit 
	ret
ret1:
	push ebx  ; Win32 stdcall calling convention
	add ecx, WSIZE
	mov _GlobalRp, ecx
	inc _GlobalRtp
	mov ebx, _GlobalRtp
	mov al, [ebx]
	pop ebx
        cmp al, OP_ADDR
        jnz E_ret_stk_corrupt
	mov eax, [ecx]
        mov _GlobalIp, eax	; reset the instruction ptr
        xor eax, eax
        ret

L_tobody:
	LDSP
	INC_DSP
	mov ecx, [ebx]	; code address
	inc ecx		; the data address is offset by one
	mov ecx, [ecx]
	mov [ebx], ecx
	ret
;
; For precision delays, use MS instead of USLEEP
; Use USLEEP when task can be put to sleep and reawakened by OS
;
L_usleep:
	  mov eax, WSIZE
        add _GlobalSp, eax
        INC_DTSP
        LDSP
        mov eax, [ebx]
        cdq
        mov ebx, 1000
        idiv ebx
        push eax
        call _Sleep@4
        ; pop eax
        xor eax, eax
        ret
L_ms:
        LDSP
        INC_DSP
        mov eax, 1000
        imul D[ebx]
        mov [ebx], eax
        call L_usleep
        ret
L_fill:
        _SWAP
        mov eax, WSIZE
        add _GlobalSp, eax
        INC_DTSP
        LDSP
        mov ebx, [ebx]
        push ebx
        add _GlobalSp, eax
        INC_DTSP
        LDSP
        mov ebx, [ebx]
        push  ebx
        add _GlobalSp, eax
        INC_DTSP
        mov ebx, _GlobalTp
        mov al, [ebx]
        cmp al, OP_ADDR
        jz fill2
        pop ebx
        pop ebx
        mov eax, E_NOT_ADDR
        jmp fillexit
fill2:  LDSP
        mov ebx, [ebx]
        push ebx
        call _memset
        add esp, 12
        xor eax, eax
fillexit:
        ret
L_erase:
        LDSP
        mov D[ebx], 0
        DEC_DSP
        STSP
        DEC_DTSP
        call L_fill
        ret
L_blank:    
	LDSP
	mov D[ebx], 32
	DEC_DSP
	STSP
	DEC_DTSP
	call L_fill
	ret
L_move:
	mov eax, WSIZE
	add _GlobalSp, eax
	INC_DTSP
	LDSP
	mov ebx, [ebx]
	push ebx
	_SWAP
	mov eax, WSIZE
	add _GlobalSp, eax
	INC_DTSP
	mov ebx, _GlobalTp
	mov al, [ebx]
	cmp al, OP_ADDR
	jz move2
	pop ebx
	mov eax, E_NOT_ADDR
	ret
move2:  LDSP
	mov ebx, [ebx]
	push ebx
	mov eax, WSIZE
	add _GlobalSp, eax
	INC_DTSP
	mov ebx, _GlobalTp
	mov al, [ebx]
	cmp al, OP_ADDR
	jz move3
	pop ebx
	pop ebx
	mov eax, E_NOT_ADDR
	ret
move3:  LDSP
	mov ebx, [ebx]
	push ebx
	call _memmove
	add esp, 12
	xor eax, eax
	ret
L_cmove:
        LDSP
	mov eax, WSIZE
        add ebx, eax
        mov ecx, [ebx]		; nbytes in ecx
        cmp ecx, 0
	jnz cmove1
	add ebx, 2*WSIZE
        STSP
	add _GlobalTp, 3
	xor eax, eax
	ret
cmove1: INC_DTSP
	add ebx, eax
	mov edx, [ebx] 		; dest addr in edx
	STSP
	INC_DTSP
        mov ebx, _GlobalTp
        mov al, [ebx]
        cmp al, OP_ADDR
        jz cmove2
        mov eax, E_NOT_ADDR
        ret
cmove2: LDSP
	mov eax, WSIZE	
	add ebx, eax
	mov eax, [ebx]
	STSP
	INC_DTSP
        mov ebx, _GlobalTp
        mov bl, [ebx]
        cmp bl, OP_ADDR
        jz cmove3
        mov eax, E_NOT_ADDR
        ret
cmove3: mov ebx, eax  		; src addr in ebx
cmoveloop:
	mov al, [ebx]
	mov [edx], al
	inc ebx
	inc edx
	loop cmoveloop
        xor eax, eax
        ret
L_cmovefrom:
        mov eax, WSIZE
        add _GlobalSp, eax
        inc _GlobalTp
        mov ebx, _GlobalSp
        mov ecx, [ebx]	; load count register
        add _GlobalSp, eax
        inc _GlobalTp
        mov ebx, _GlobalTp
        mov al, [ebx]
        cmp al, OP_ADDR
        jz cmovefrom2
        mov eax, E_NOT_ADDR
        ret
cmovefrom2:
        mov ebx, _GlobalSp
        mov ebx, [ebx]
        mov eax, ecx
        dec eax
        add ebx, eax
        mov edx, ebx	; dest addr in edx
        mov eax, WSIZE
        add _GlobalSp, eax
        inc _GlobalTp
        mov ebx, _GlobalTp
        mov al, [ebx]
        cmp al, OP_ADDR
        jz cmovefrom3
        mov eax, E_NOT_ADDR
        ret
cmovefrom3:
        mov ebx, _GlobalSp
        mov ebx, [ebx]
        mov eax, ecx
	cmp eax, 0
        jnz cmovefrom4
	ret
cmovefrom4:
        dec eax
        add ebx, eax	; src addr in ebx
cmovefromloop:
        mov al, [ebx]
        dec ebx
        xchg edx, ebx
        mov B[ebx], al
        dec ebx
        xchg edx, ebx
        loop cmovefromloop
        xor eax, eax
        ret

L_slashstring:
        LDSP
        _DROP
        mov ecx, [ebx]
        INC_DSP
        sub [ebx], ecx
        INC_DSP
        add [ebx], ecx
        NEXT

L_call:
        LDSP
        _DROP
        jmp [ebx]

L_push_r:
        PUSH_R
        NEXT

L_pop_r:
        POP_R
        NEXT

L_twopush_r:
	LDSP
	INC_DSP
	mov edx, [ebx]
	INC_DSP
	mov eax, [ebx]
	STSP
	mov ebx, _GlobalRp
	mov [ebx], eax
	sub ebx, WSIZE
	mov [ebx], edx
	sub ebx, WSIZE
	mov _GlobalRp, ebx
	mov ebx, _GlobalTp
	inc ebx
	mov ax, W[ebx]
	inc ebx
	mov _GlobalTp, ebx
	mov ebx, _GlobalRtp
	dec ebx
	mov W[ebx], ax
	dec ebx
	mov _GlobalRtp, ebx
	xor eax, eax
	NEXT

L_twopop_r:
	mov ebx, _GlobalRp
	add ebx, WSIZE
	mov edx, [ebx]
	add ebx, WSIZE
	mov eax, [ebx]
	mov _GlobalRp, ebx
	LDSP
	mov [ebx], eax
	sub ebx, WSIZE
	mov [ebx], edx
	sub ebx, WSIZE
	STSP
	mov ebx, _GlobalRtp
	inc ebx
	mov ax, W[ebx]
	inc ebx
	mov _GlobalRtp, ebx
	mov ebx, _GlobalTp
	dec ebx
	mov W[ebx], ax
	dec ebx
	mov _GlobalTp, ebx
	xor eax, eax				
	NEXT

L_puship:
        mov eax, ebp
        mov ebx, _GlobalRp
        mov [ebx], eax
	mov eax, WSIZE
        sub _GlobalRp, eax
        mov ebx, _GlobalRtp
        mov al, OP_ADDR
	mov B[ebx], al
        dec _GlobalRtp
        xor eax, eax
        NEXT

L_execute:
        mov ecx, ebp
        mov ebx, _GlobalRp
        mov [ebx], ecx
        mov eax, WSIZE
        sub ebx, eax
        mov _GlobalRp, ebx
        mov ebx, _GlobalRtp
        mov B[ebx], OP_ADDR
        dec ebx
        mov _GlobalRtp, ebx
        LDSP
        add ebx, eax
        STSP
        mov eax, [ebx]
        dec eax
        mov ebp, eax
        INC_DTSP
        xor eax, eax
        NEXT

L_definition:
        mov ebx, ebp
	mov eax, WSIZE
	inc ebx
	mov ecx, [ebx]  ; address to execute
	add ebx, 3
	mov edx, ebx
	mov ebx, _GlobalRp
	mov [ebx], edx
	sub ebx, eax
	mov _GlobalRp, ebx
	mov ebx, _GlobalRtp
	mov B[ebx], OP_ADDR
	dec ebx
	mov _GlobalRtp, ebx
	dec ecx
	mov ebp, ecx
        xor eax, eax	
	NEXT	

L_rfetch:
        mov ebx, _GlobalRp
        add ebx, WSIZE
        mov eax, [ebx]
        LDSP
        mov [ebx], eax
        sub _GlobalSp, WSIZE
        mov ebx, _GlobalRtp
        inc ebx
        mov al, [ebx]
        mov ebx, _GlobalTp
        mov B[ebx], al
        dec _GlobalTp
        xor eax, eax
        NEXT

L_tworfetch:
        mov ebx, _GlobalRp
        add ebx, WSIZE
        mov edx, [ebx]
        add ebx, WSIZE
        mov eax, [ebx]
        LDSP
        mov [ebx], eax
        DEC_DSP
        mov [ebx], edx
        DEC_DSP
        STSP
        mov ebx, _GlobalRtp
        inc ebx
        mov ax, W[ebx]
        inc ebx
        mov ebx, _GlobalTp
        dec ebx
        mov W[ebx], ax
        dec ebx
        mov _GlobalTp, ebx
        xor eax, eax				
	NEXT

L_rpfetch:
        LDSP
        mov eax, _GlobalRp
        add eax, WSIZE
        mov [ebx], eax
        DEC_DSP
        STSP
        mov ebx, _GlobalTp
        mov B[ebx], OP_ADDR
        dec ebx
        mov _GlobalTp, ebx
        xor eax, eax
        NEXT

L_spfetch:
        mov eax, _GlobalSp
        mov ebx, eax
        add eax, WSIZE
        mov [ebx], eax
        DEC_DSP
        STSP
        mov ebx, _GlobalTp
        mov B[ebx], OP_ADDR
        dec ebx
        mov _GlobalTp, ebx
        xor eax, eax
        NEXT

L_i:
        mov ebx, _GlobalRtp
        mov al, [ebx+3]
        mov ebx, _GlobalTp
        mov B[ebx], al
        dec ebx
        mov _GlobalTp, ebx
        mov ebx, _GlobalRp
        mov eax, [ebx+3*WSIZE]
        LDSP
        mov [ebx], eax
        mov eax, WSIZE
        sub ebx, eax
        STSP
        xor eax, eax
        NEXT

L_j:
        mov ebx, _GlobalRtp
        mov al, [ebx+6]
        mov ebx, _GlobalTp
        mov B[ebx], al
        dec ebx
        mov _GlobalTp, ebx
        mov ebx, _GlobalRp
        mov eax, [ebx + 6*WSIZE]
        LDSP
        mov [ebx], eax
        mov eax, WSIZE
        sub ebx, eax
        STSP
        xor eax, eax
        NEXT

L_rtloop:
        mov ebx, _GlobalRtp
        inc ebx
        mov al, [ebx]
        cmp al, OP_ADDR
        jnz E_ret_stk_corrupt
        mov ebx, _GlobalRp
        mov eax, WSIZE
        add ebx, eax
        mov edx, [ebx]
        add ebx, eax
        mov ecx, [ebx]
        add ebx, eax
        mov eax, [ebx]
        inc eax
        cmp eax, ecx
        jz L_rtunloop
        mov [ebx], eax	; set loop counter to next value
        mov ebp, edx	; set instruction ptr to start of loop
        xor eax, eax
        NEXT
L_rtunloop:
	UNLOOP
        xor eax, eax
        NEXT
L_rtplusloop:
	push ebp
        mov ebx, _GlobalRtp
        inc ebx
        mov al, [ebx]
        cmp al, OP_ADDR
        jnz E_ret_stk_corrupt
        mov eax, WSIZE
        LDSP
        add ebx, eax
        mov ebp, [ebx]          ; get loop increment
        STSP
        INC_DTSP
        mov ebx, _GlobalRp
        add ebx, eax            ; get ip and save in edx
        mov edx, [ebx]
        add ebx, eax
        mov ecx, [ebx]          ; get terminal count in ecx
        add ebx, eax
        mov eax, [ebx]          ; get current loop index
        add eax, ebp            ; new loop index
        cmp ebp, 0
        jl plusloop1            ; loop inc < 0?
	; positive loop increment
        cmp eax, ecx
        jl plusloop2           ; is new loop index < ecx?
	add ecx, ebp
	cmp eax, ecx
	jge plusloop2          ; is new index >= ecx + inc?
	pop ebp
	xor eax, eax
	UNLOOP
	NEXT
plusloop1:                    ; negative loop increment
	dec ecx
        cmp eax, ecx
        jg plusloop2          ; is new loop index > ecx-1?
	add ecx, ebp
	cmp eax, ecx
	jle plusloop2
	pop ebp
	xor eax, eax
	UNLOOP
	NEXT
plusloop2:
	pop ebp
        mov [ebx], eax	; set loop counter to incremented value
        mov ebp, edx	 ; set instruction ptr to start of loop
        xor eax, eax
        NEXT

L_jz:
	LDSP
	_DROP
	mov eax, [ebx]
	cmp eax, 0
	jz jz1
	mov eax, 4
	add ebp, eax        ; do not jump
	xor eax, eax
	NEXT
jz1:    mov ecx, ebp
	inc ecx
	mov eax, [ecx]      ; get the relative jump count
	dec eax
	add ebp, eax
	xor eax, eax
	NEXT
L_jnz:                      ; not implemented
        ret

L_jmp:
	mov ecx, ebp
	inc ecx
	mov eax, [ecx]      ; get the relative jump count
	add ecx, eax
	sub ecx, 2
	mov ebp, ecx        ; set instruction ptr
	xor eax, eax
	NEXT

L_calladdr:
	inc ebp
	mov ecx, ebp ; address to execute (intrinsic Forth word or other)
	add ebp, 3
	mov _GlobalIp, ebp
        jmp [ecx]

L_count:
        mov ebx, _GlobalTp
        mov al, B[ebx + 1]
        cmp al, OP_ADDR
        jnz E_not_addr
        mov B[ebx], OP_IVAL
        DEC_DTSP
        LDSP
        mov ebx, [ebx + WSIZE]
        xor eax, eax
        mov al, B[ebx]
        LDSP
        inc D[ebx + WSIZE]
        mov [ebx], eax
        sub _GlobalSp, WSIZE
        xor eax, eax
        ret

L_ival:
	LDSP
	mov ecx, ebp
	inc ecx
	mov eax, [ecx]
	add ecx, WSIZE-1
	mov ebp, ecx
	mov [ebx], eax
	DEC_DSP
	STSP
	STD_IVAL
	xor eax, eax
	NEXT

L_addr:
	LDSP
	mov ecx, ebp
	inc ecx
	mov eax, [ecx]
	add ecx, WSIZE-1
	mov ebp, ecx
	mov [ebx], eax
	DEC_DSP
	STSP
	STD_ADDR
	xor eax, eax
	NEXT

L_ptr:
        LDSP
        mov ecx, ebp
        inc ecx
        mov eax, [ecx]
        add ecx, WSIZE-1
        mov ebp, ecx
        mov eax, [eax]
        mov [ebx], eax
        DEC_DSP
        STSP
        STD_ADDR
        xor eax, eax
        NEXT

L_2val:
L_fval:
        mov ebx, ebp
        inc ebx
	mov ecx, _GlobalSp
	sub ecx, WSIZE
	mov eax, [ebx]
	mov [ecx], eax
	mov eax, [ebx+WSIZE]
	mov [ecx+WSIZE], eax
	sub ecx, WSIZE
	mov _GlobalSp, ecx
	add ebx, 2*WSIZE-1
	mov ebp, ebx
	mov ebx, _GlobalTp
	mov B[ebx], OP_IVAL
	dec ebx
	mov B[ebx], OP_IVAL
	dec ebx
	mov _GlobalTp, ebx
	xor eax, eax	  
        NEXT

L_and:
	  mov ebx, _GlobalSp
	  add ebx, WSIZE
	  mov eax, [ebx]
	  add ebx, WSIZE
	  mov ecx, ebx
	  mov ebx, [ebx]
	  and eax, ebx
	  mov ebx, ecx
	  mov [ebx], eax
	  sub ebx, WSIZE
	  mov _GlobalSp, ebx
	  inc _GlobalTp
	  mov ebx, _GlobalTp
	  mov B[ebx+1], OP_IVAL
	  xor eax, eax
        ret

L_or:
        add _GlobalSp, WSIZE
        inc _GlobalTp
        mov ebx, _GlobalSp
        mov eax, [ebx]
        mov ebx, [ebx + WSIZE]
        or eax, ebx
        mov ebx, _GlobalSp
        mov [ebx + WSIZE], eax
        mov ebx, _GlobalTp
        mov B[ebx + 1], OP_IVAL
        xor eax, eax
        ret

L_not:
        mov ebx, _GlobalSp
        mov eax, [ebx + WSIZE]
        not eax
        mov [ebx + WSIZE], eax
        xor eax, eax
        ret

L_xor:
        add _GlobalSp, WSIZE
        inc _GlobalTp
        mov ebx, _GlobalSp
        mov eax, [ebx]
        mov ebx, [ebx + WSIZE]
        xor eax, ebx
        mov ebx, _GlobalSp
        mov [ebx + WSIZE], eax
        mov ebx, _GlobalTp
        mov B[ebx + 1], OP_IVAL
        xor eax, eax
        ret

L_lshift:
        LDSP
        _DROP
	mov ecx, [ebx]
	mov eax, [ebx + WSIZE]
        shl eax, cl
	mov [ebx + WSIZE], eax
	xor eax, eax
        NEXT

L_rshift:
        LDSP
	_DROP
	mov ecx, [ebx]
	mov eax, [ebx + WSIZE]
	shr eax, cl
	mov [ebx + WSIZE], eax
	xor eax, eax
	NEXT

L_eq:
        REL_DYADIC sete
        NEXT

L_ne:
        REL_DYADIC setne
        NEXT

L_ult:
        REL_DYADIC setb
        NEXT

L_ugt:
        REL_DYADIC seta
        NEXT

L_lt:
        REL_DYADIC setl
        NEXT

L_gt:
        REL_DYADIC setg
        NEXT

L_le:
        REL_DYADIC setle
        NEXT

L_ge:
        REL_DYADIC setge
        NEXT

L_zeroeq:
        REL_ZERO setz
        NEXT

L_zerone:
        REL_ZERO setnz
        NEXT

L_zerolt:
        REL_ZERO setl
        NEXT

L_zerogt:
        REL_ZERO setg
        NEXT

L_within:
        LDSP                      ; stack: a b c
        mov ecx, [ebx + 2*WSIZE]  ; ecx = b
        mov eax, [ebx + WSIZE]    ; eax = c
        sub eax, ecx              ; eax = c - b
        INC_DSP
        INC_DSP
        mov edx, [ebx + WSIZE]    ; edx = a
        sub edx, ecx              ; edx = a - b
        cmp edx, eax
        mov eax, 0
        setb al
        neg eax
        mov D[ebx + WSIZE], eax
        STSP
        mov ebx, _GlobalTp
        add ebx, 3
        mov B[ebx], OP_IVAL
        dec ebx
        mov _GlobalTp, ebx
        xor eax, eax
        NEXT

L_deq:
        mov ebx, _GlobalTp
        add ebx, 4
        mov B[ebx], OP_IVAL
        dec ebx
        mov _GlobalTp, ebx
        LDSP
        INC_DSP
        mov edx, [ebx]
        INC_DSP
        mov ecx, [ebx]
        INC_DSP
        STSP
        mov eax, [ebx]
        sub eax, edx
        INC_DSP
        mov edx, [ebx]
        sub edx, ecx
        or  eax, edx
        cmp eax, 0
        mov eax, 0
        setz al
        neg eax
        mov [ebx], eax
        xor eax, eax
        NEXT

L_dzeroeq:
        mov ebx, _GlobalTp
        add ebx, 2
        mov B[ebx], OP_IVAL
        dec ebx
        mov _GlobalTp, ebx
        LDSP
        INC_DSP
        STSP
        mov eax, [ebx]
        INC_DSP
        or  eax, [ebx]
        cmp eax, 0
        mov eax, 0
        setz al
        neg eax
        mov [ebx], eax
        xor eax, eax
        NEXT

L_dzerolt:
        REL_ZERO setl
        mov eax, [ebx]
        mov [ebx + WSIZE], eax
        STSP
        INC_DTSP
        xor eax, eax
        NEXT

L_dlt:
        DLT
        NEXT

L_dult: ; b = (d1.hi u< d2.hi) OR ((d1.hi = d2.hi) AND (d1.lo u< d2.lo))
        LDSP
        mov ecx, WSIZE
        xor edx, edx
        add ebx, ecx
        mov eax, [ebx]
        cmp D[ebx + 2*WSIZE], eax
        sete dl
        setb dh
        add ebx, ecx
        mov eax, [ebx]
        add ebx, ecx
        STSP
        add ebx, ecx
        cmp [ebx], eax
        setb al
        and dl, al
        or dl, dh
        xor eax, eax
        mov al, dl
        neg eax
        mov [ebx], eax
        mov eax, _GlobalTp
        add eax, 4
        mov B[eax], OP_IVAL
        dec eax
        mov _GlobalTp, eax
        xor eax, eax
        NEXT

L_querydup:
        LDSP
        mov eax, [ebx + WSIZE]
        cmp eax, 0
        je L_querydupexit
        mov [ebx], eax
        DEC_DSP
        STSP
        mov ebx, _GlobalTp
        mov al, B[ebx + 1]
        mov B[ebx], al
        DEC_DTSP
        xor eax, eax
L_querydupexit:
        NEXT

L_drop:
        LDSP
        _DROP
        NEXT

L_dup:
	LDSP
	_DUP
	NEXT

L_swap:
	_SWAP
	NEXT

L_over:
	_OVER
	NEXT

L_rot:
        push ebp
        LDSP
	mov eax, WSIZE
	add ebx, eax    ; ebx = tos
	mov ebp, ebx    ; ebp = tos
	add ebx, eax
	add ebx, eax    ; ebx = tos + 2 cells
	mov ecx, [ebx]  ; ecx = [tos + 2 cells]
	mov edx, [ebp]  ; edx = [tos]
	mov [ebp], ecx  ; [tos] = ecx
	add ebp, eax    ; ebp = tos + 1 cell
	mov ecx, [ebp]  ; ecx = [tos + 1 cell]
	mov [ebp], edx  ; [tos + 1 cell] = edx
	mov [ebx], ecx  ; [tos + 2 cells] = ecx
	mov ebx, _GlobalTp
	inc ebx
	mov ebp, ebx
	mov cx, [ebx]
	add ebx, 2
	mov al, [ebx]
	mov B[ebp], al
	inc ebp
	mov W[ebp], cx
	xor eax, eax
	pop ebp
	NEXT

L_minusrot:
        LDSP
        mov eax, [ebx + WSIZE]
        mov [ebx], eax
        add ebx, WSIZE
        mov eax, [ebx + WSIZE]
        mov [ebx], eax
        add ebx, WSIZE
        mov eax, [ebx + WSIZE]
        mov [ebx], eax
        mov eax, [ebx - 2*WSIZE]
        mov [ebx + WSIZE], eax
        mov ebx, _GlobalTp
        mov al, [ebx + 1]
        mov B[ebx], al
        inc ebx
        mov ax, [ebx + 1]
        mov W[ebx], ax
        mov al, [ebx - 1]
        mov B[ebx + 2], al
        xor eax, eax
        NEXT

L_nip:
        _SWAP
        add _GlobalSp, WSIZE
        INC_DTSP
        NEXT

L_tuck:
        _SWAP
        _OVER
        NEXT

L_pick:
        LDSP
        mov eax, [ebx + WSIZE]
        inc eax
        inc eax
        imul eax, WSIZE
        add ebx, eax
        mov eax, [ebx]
        mov ebx, _GlobalSp
        mov [ebx], eax
        mov eax, [ebx + WSIZE]
        inc eax
        inc eax
        mov ebx, _GlobalTp
        add ebx, eax
        mov al, [ebx]
        mov ebx, _GlobalTp
        mov B[ebx + 1], al
        mov ebx, _GlobalSp
        mov eax, [ebx]
        mov [ebx + WSIZE], eax
        xor eax, eax
        ret

L_roll:
        add _GlobalSp, WSIZE
        inc _GlobalTp
        mov ebx, _GlobalSp
        mov eax, [ebx]
        inc eax
        push eax
        push eax
        push eax
        push ebx
        imul eax, WSIZE
        add ebx, eax	; addr of item to roll
        mov eax, [ebx]
        pop ebx
        mov [ebx], eax
        pop eax		; number of cells to copy
        mov ecx, eax
        imul eax, WSIZE
        add ebx, eax
        mov edx, ebx	; dest addr
        sub ebx, WSIZE	; src addr
rollloop:
        mov eax, [ebx]
        sub ebx, WSIZE
        xchg edx, ebx
        mov [ebx], eax
        sub ebx, WSIZE
        xchg edx, ebx
        loop rollloop

        pop eax             ; roll the typestack
        mov ebx, _GlobalTp
        add ebx, eax
        mov al, B[ebx]
        mov ebx, _GlobalTp
        mov B[ebx], al
        pop eax
        mov ecx, eax
        add ebx, eax
        mov edx, ebx
        dec ebx
rolltloop:
        mov al, B[ebx]
        dec ebx
        xchg edx, ebx
        mov B[ebx], al
        dec ebx
        xchg edx, ebx
        loop rolltloop
        xor eax, eax
        ret

_L_depth:
	push ebx  ; Win32 stdcall calling convention
        LDSP
        mov eax, _BottomOfStack
        sub eax, ebx
        mov D[ebx], WSIZE
        mov edx, 0
        idiv D[ebx]
        mov [ebx], eax
        sub _GlobalSp, WSIZE
        mov ebx, _GlobalTp
        mov B[ebx], OP_IVAL
        dec _GlobalTp
        xor eax, eax
	pop ebx
        ret

L_2drop:
        add _GlobalSp, 2*WSIZE
        add _GlobalTp, 2
        NEXT

L_f2drop:
        FDROP
        FDROP
        NEXT

L_f2dup:
        FOVER
        FOVER
        NEXT

L_2dup:
	push ebx  ; Win32 stdcall calling convention
        LDSP
	mov ecx, ebx
	add ebx, WSIZE
	mov edx, [ebx]
	add ebx, WSIZE
	mov eax, [ebx]
	mov ebx, ecx
	mov [ebx], eax
	DEC_DSP
	mov [ebx], edx
	DEC_DSP
	STSP
	mov ebx, _GlobalTp
	inc ebx
	mov ax, W[ebx]
	sub ebx, 2
	mov W[ebx], ax
	dec ebx
	mov _GlobalTp, ebx
	xor eax, eax
	pop ebx
	ret

L_2swap:
        FSWAP
	NEXT

L_2over:
        FOVER
	NEXT

L_2rot:
        LDSP
        INC_DSP
        mov ecx, ebx
        mov edx, [ebx]
        INC_DSP
        mov eax, [ebx]
        INC_DSP
        xchg [ebx], edx
        INC_DSP
        xchg [ebx], eax
        INC_DSP
        xchg [ebx], edx
        INC_DSP
        xchg [ebx], eax
        mov ebx, ecx
        mov [ebx], edx
        add ebx, WSIZE
        mov [ebx], eax
        mov ebx, _GlobalTp
        inc ebx
        mov ecx, ebx
        mov ax, W[ebx]
        add ebx, 2
        xchg W[ebx], ax
        add ebx, 2
        xchg W[ebx], ax
        mov ebx, ecx
        mov W[ebx], ax
        xor eax, eax
        NEXT

L_question:
        call L_fetch
        cmp eax, 0
        jnz questionexit
        call _CPP_dot
questionexit:
        ret

L_ulfetch:
L_slfetch:
L_fetch:
        mov edx, _GlobalSp
        mov ebx, _GlobalTp
        inc ebx
        mov al, [ebx]
        cmp al, OP_ADDR
        jnz fetcherror
        mov B[ebx], OP_IVAL
        add edx, WSIZE
	mov ebx, [edx]
	mov eax, [ebx]
	mov [edx], eax
        xor eax, eax
        ret
fetcherror:
        mov eax, E_NOT_ADDR
        ret

L_lstore:
L_store:
        mov ebx, _GlobalTp
        inc ebx
        mov al, B[ebx]
        cmp al, OP_ADDR
        jnz E_not_addr
        mov eax, WSIZE
        LDSP
        add ebx, eax
        mov ecx, [ebx]          ; address to store in ecx
        add ebx, eax
        mov edx, [ebx]          ; value to store in edx
        STSP
        mov [ecx], edx
        INC2_DTSP
        xor eax, eax
        NEXT

L_afetch:
	mov edx, _GlobalSp
	mov ebx, _GlobalTp
	inc ebx
	mov al, B[ebx]
	cmp al, OP_ADDR
	jnz E_not_addr
	mov B[ebx], OP_ADDR
	add edx, WSIZE
	mov ebx, [edx]
	mov eax, [ebx]
	mov [edx], eax
	xor eax, eax
        NEXT

L_cfetch:
        mov ebx, _GlobalTp
	inc ebx
	mov al, B[ebx]
        cmp al, OP_ADDR
        jnz E_not_addr
        mov B[ebx], OP_IVAL
        xor eax, eax
        LDSP
	INC_DSP
	mov ecx, [ebx]
	mov al, B[ecx]
	mov [ebx], eax
	xor eax, eax
        NEXT

L_cstore:
	mov edx, _GlobalTp
	inc edx
	mov al, B[edx]
	cmp al, OP_ADDR
	jnz E_not_addr
	LDSP
	INC_DSP
	mov ecx, [ebx]	; address to store
	INC_DSP
	mov eax, [ebx]	; value to store
	mov B[ecx], al
	STSP
	inc edx
	mov _GlobalTp, edx
	xor eax, eax
	NEXT

L_swfetch:
        mov ebx, _GlobalTp
        mov al, [ebx + 1]
        cmp al, OP_ADDR
        jnz E_not_addr
        mov B[ebx + 1], OP_IVAL
        LDSP
        mov ebx, [ebx + WSIZE]
        mov ax, W[ebx]
        cwde
        LDSP
        mov [ebx + WSIZE], eax
        xor eax, eax
        NEXT

L_uwfetch:
        mov ecx, _GlobalTp
        mov al, [ecx +1]
        cmp al, OP_ADDR
        jnz E_not_addr
        mov B[ecx + 1], OP_IVAL
        LDSP
        mov ecx, [ebx + WSIZE]
        mov ax, W[ecx]
        mov [ebx + WSIZE], eax
        xor eax, eax
        NEXT

L_wstore:
        add _GlobalSp, WSIZE
        INC_DTSP
        mov ebx, _GlobalTp
        mov al, B[ebx]
        cmp al, OP_ADDR
        jnz E_not_addr
        LDSP
        mov eax, [ebx]
        push eax
        INC_DSP
        mov eax, [ebx]
        pop ebx
        mov W[ebx], ax
        add _GlobalSp, WSIZE
        INC_DTSP
        xor eax, eax
        NEXT

L_sffetch:
        add _GlobalSp, WSIZE
        INC_DTSP
        mov ebx, _GlobalTp
        mov al, [ebx]
        cmp al, OP_ADDR
        jnz E_not_addr
        mov B[ebx], OP_IVAL
        dec ebx
        mov B[ebx], OP_IVAL
        DEC_DTSP
        DEC_DTSP
        LDSP
        mov ebx, [ebx]
        FLD D[ebx]
        sub _GlobalSp, WSIZE
        LDSP
        FSTP Q[ebx]
        sub _GlobalSp, WSIZE
        xor eax, eax
        NEXT

L_sfstore:
        add _GlobalSp, WSIZE
        INC_DTSP
        mov ebx, _GlobalTp
        mov al, [ebx]
        cmp al, OP_ADDR
        jnz E_not_addr
        LDSP
        INC_DSP
        FLD Q[ebx]              ; load the f number into NDP
        DEC_DSP
        mov ebx, [ebx]          ; load the dest address
        FSTP D[ebx]             ; store as single precision float
        add _GlobalSp, 2*WSIZE
        INC2_DTSP
        xor eax, eax
        NEXT

L_2fetch:
L_dffetch:
        mov ebx, _GlobalTp
        inc ebx
        mov al, [ebx]
        cmp al, OP_ADDR
        jnz E_not_addr
	mov B[ebx], OP_IVAL
	dec ebx
	mov B[ebx], OP_IVAL
	dec ebx
	mov _GlobalTp, ebx
        LDSP
	mov edx, ebx
        INC_DSP
        mov ecx, [ebx]      ; address to fetch from in ecx
	mov eax, [ecx]
	mov [edx], eax
	add ecx, WSIZE
	mov eax, [ecx]
	mov [ebx], eax
	sub edx, WSIZE
	mov _GlobalSp, edx
	xor eax, eax
	NEXT

L_2store:
L_dfstore:
        mov ebx, _GlobalTp
        inc ebx
        mov al, [ebx]
        cmp al, OP_ADDR
        jnz E_not_addr
	add ebx, 2
	mov _GlobalTp, ebx
        LDSP
	mov edx, WSIZE
        add ebx, edx
	mov eax, ebx
	mov ebx, [ebx]	; address to store
	add eax, edx
	mov ecx, [eax]
	mov [ebx], ecx
	add eax, edx
	add ebx, edx
	mov ecx, [eax]
	mov [ebx], ecx
	mov _GlobalSp, eax
	xor eax, eax
	NEXT

L_inc:
        LDSP
        inc D[ebx + WSIZE]
        NEXT

L_dec:
        LDSP
        dec D[ebx + WSIZE]
        NEXT

L_twoplus:
        LDSP
        inc D[ebx + WSIZE]
        inc D[ebx + WSIZE]
        NEXT

L_twominus:
        LDSP
        dec D[ebx + WSIZE]
        dec D[ebx + WSIZE]
        NEXT

L_abs:
	_ABS
	NEXT

L_neg:
        LDSP
        neg D[ebx + WSIZE]
        NEXT

L_max:
        add _GlobalSp, WSIZE
        mov ebx, _GlobalSp
        mov eax, [ebx]
        mov ebx, [ebx + WSIZE]
        cmp ebx, eax
        jl max1
        mov eax, ebx
        mov ebx, _GlobalSp
        mov [ebx + WSIZE], eax
        jmp maxexit
max1:   
        LDSP
        mov [ebx + WSIZE], eax
maxexit:
        INC_DTSP
        xor eax, eax
        NEXT

L_min:
        add _GlobalSp, WSIZE
        mov ebx, _GlobalSp
        mov eax, [ebx]
        mov ebx, [ebx + WSIZE]
        cmp ebx, eax
        jg min1
        mov eax, ebx
        LDSP
        mov [ebx + WSIZE], eax
        jmp minexit
min1:   
        LDSP
        mov [ebx + WSIZE], eax
minexit:
        INC_DTSP
        xor eax, eax
        NEXT

L_dmax:
        FOVER
        FOVER
        DLT
        INC_DTSP
        LDSP
        INC_DSP
        mov eax, [ebx]
        STSP
        cmp eax, 0
        jne LONG dmin1
        FDROP
        xor eax, eax
        NEXT

L_dmin:
        FOVER
        FOVER
        DLT
        INC_DTSP
        mov ecx, WSIZE
        LDSP
        add ebx, ecx
        mov eax, [ebx]
        STSP
        cmp eax, 0
        je dmin1
        FDROP
        xor eax, eax
	NEXT
dmin1:
        FSWAP
        FDROP
        xor eax, eax
        NEXT

;  L_dtwostar and L_dtwodiv are valid for two's-complement systems
L_dtwostar:
        LDSP
        INC_DSP
        mov eax, [ebx + WSIZE]
        mov ecx, eax
        sal eax, 1
        mov [ebx + WSIZE], eax
        shr ecx, 31
        mov eax, [ebx]
        sal eax, 1
        or  eax, ecx
        mov [ebx], eax
        xor eax, eax
        NEXT

L_dtwodiv:
        LDSP
        INC_DSP
        mov eax, [ebx]
        mov ecx, eax
        sar eax, 1
        mov [ebx], eax
        shl ecx, 31
        mov eax, [ebx + WSIZE]
        shr eax, 1
        or  eax, ecx
        mov [ebx + WSIZE], eax
        xor eax, eax
        NEXT

L_twostar:
        LDSP
        sal D[ebx + WSIZE], 1
        NEXT

L_twodiv:
        LDSP
        sar D[ebx + WSIZE], 1
        NEXT

L_add:
	LDSP
        mov eax, WSIZE
        add ebx, eax
        mov eax, [ebx]
        add [ebx + WSIZE], eax
        STSP
        mov ebx, _GlobalTp
        inc ebx
        mov _GlobalTp, ebx
        mov ax, W[ebx]
        and al, ah  ; and the two type to preserve address
        inc ebx
        mov B[ebx], al
        xor eax, eax
        NEXT

L_sub:
	LDSP
	_DROP            ; result will have type of first operand
	mov eax, [ebx]
	sub [ebx + WSIZE], eax
	xor eax, eax
	NEXT

L_mul:
	LDSP
        mov ecx, WSIZE
        add ebx, ecx
        STSP
        mov eax, [ebx]
        add ebx, ecx
        imul D[ebx]
        mov [ebx], eax
        INC_DTSP
        xor eax, eax
        NEXT

L_div:
        add _GlobalSp, WSIZE
        INC_DTSP
        LDSP
        mov eax, [ebx]
        cmp eax, 0
        jz E_div_zero
        INC_DSP
        mov eax, [ebx]
        cdq
        idiv D[ebx - WSIZE]
        mov [ebx], eax
        xor eax, eax
divexit:
        ret

L_mod:
        call L_div
	cmp eax, 0
	jnz divexit
        mov [ebx], edx
        NEXT

L_slashmod:
        call L_div
        cmp eax, 0
	jnz divexit
	DEC_DSP
        mov [ebx], edx
        DEC_DSP
        STSP
        DEC_DTSP
        _SWAP
        NEXT

L_starslash:
        mov eax, WSIZE
        sal eax, 1
        add _GlobalSp, eax
        mov ebx, _GlobalSp
        mov eax, [ebx + WSIZE]
        imul D[ebx]
        idiv D[ebx - WSIZE]
        mov [ebx + WSIZE], eax
        inc _GlobalTp
        inc _GlobalTp
        xor eax, eax
        ret

L_starslashmod:
        call L_starslash
        mov [ebx], edx
        DEC_DSP
        STSP
        DEC_DTSP
        _SWAP
        ret

L_plusstore:
        mov ebx, _GlobalTp
        mov al, [ebx + 1]
        cmp al, OP_ADDR
        jnz E_not_addr
        LDSP
        INC_DSP
        mov edx, [ebx]  ; edx = addr
        INC_DSP
        mov eax, [ebx]
        add [edx], eax
        STSP
        INC2_DTSP
        xor eax, eax
        NEXT

_L_dabs:
	push ebx ; Win32 stdcall calling convention
	LDSP
	INC_DSP
	mov ecx, [ebx]
	mov eax, ecx
	cmp eax, 0
	jl dabs_go
	xor eax, eax
	pop ebx
	ret
dabs_go:
	INC_DSP
	mov eax, [ebx]
	clc
	sub eax, 1
	not eax
	mov [ebx], eax
	mov eax, ecx
	sbb eax, 0
	not eax
	mov [ebx-WSIZE], eax
	xor eax, eax
	pop ebx
	ret

_L_dnegate:
	push ebx  ; Win32 stdcall calling convention
	DNEGATE
	pop ebx
	ret

_L_dplus:
	push ebx  ; Win32 stdcall calling convention
	DPLUS
	pop ebx
	ret

_L_dminus:
	push ebx  ; Win32 stdcall calling convention
	DMINUS
	pop ebx
	ret

L_umstar:
	LDSP
        mov eax, WSIZE
        add ebx, eax
        mov ecx, [ebx]
        add ebx, eax
        mov eax, ecx
        mul D[ebx]
        mov [ebx], eax
        DEC_DSP
        mov [ebx], edx
        xor eax, eax
        NEXT

L_dsstar:
        ; multiply signed double and signed to give triple length product
        LDSP
        mov ecx, WSIZE
        add ebx, ecx
        mov edx, [ebx]
        cmp edx, 0
        setl al
        add ebx, ecx
        mov edx, [ebx]
        cmp edx, 0
        setl ah
        xor al, ah     ; sign of result
        and eax, 1
        push eax
        _ABS
        LDSP
        INC_DSP
        STSP
        INC_DTSP
        call _L_dabs
        LDSP
        DEC_DSP
        STSP
        DEC_DTSP
        call _L_udmstar
        pop eax
        cmp eax, 0
        jne dsstar1
        NEXT
dsstar1:
        TNEG
        NEXT

L_umslashmod:
; Divide unsigned double length by unsigned single length to
; give unsigned single quotient and remainder. A "Divide overflow"
; error results if the quotient doesn't fit into a single word.
	LDSP
	mov eax, WSIZE
	add ebx, eax
	STSP
	mov ecx, [ebx]
	cmp ecx, 0
	jz E_div_zero
	add ebx, eax
	mov edx, 0
	mov eax, [ebx]
	div ecx
	cmp eax, 0
	jne E_div_overflow
        mov edx, [ebx]
	INC_DSP
        mov eax, [ebx]
        div ecx
        mov [ebx], edx
        DEC_DSP
        mov [ebx], eax
        INC_DTSP
        xor eax, eax
        NEXT

L_mstar:
	LDSP
        mov eax, WSIZE
        add ebx, eax
        mov ecx, [ebx]
        add ebx, eax
        mov eax, ecx
        imul D[ebx]
        mov [ebx], eax
        DEC_DSP
        mov [ebx], edx
        xor eax, eax
        NEXT

L_mplus:
	STOD
	DPLUS
	NEXT

L_mslash:
	LDSP
	mov eax, WSIZE
        INC_DTSP
	add ebx, eax
        mov ecx, [ebx]
	INC_DTSP
	add ebx, eax
	STSP
        cmp ecx, 0
        je E_div_zero
        mov edx, [ebx]
	add ebx, eax
	mov eax, [ebx]
        idiv ecx
        mov [ebx], eax
	xor eax, eax		
	NEXT

_L_udmstar:
	; multiply unsigned double and unsigned to give triple length product
	push ebx  ; Win32 stdcall convention requires preserving ebx
	LDSP
	INC_DSP
	mov ecx, [ebx]
	INC_DSP
	mov eax, [ebx]
	mul ecx
	mov [ebx-WSIZE], edx
	mov [ebx], eax
	INC_DSP
	mov eax, ecx
	mul D[ebx]
	mov [ebx], eax
	DEC_DSP
	mov eax, [ebx]
	DEC_DSP
	clc
	add eax, edx
	mov [ebx+WSIZE], eax
	mov eax, [ebx]
	adc eax, 0
	mov [ebx], eax
	xor eax, eax
	pop ebx 		
	ret

L_utsslashmod:
; Divide unsigned triple length by unsigned single length to
; give an unsigned triple quotient and single remainder.
        LDSP
        INC_DSP
        mov ecx, [ebx]          ; divisor in ecx
        cmp ecx, 0
        jz E_div_zero
        INC_DSP
        mov eax, [ebx]          ; ut3
        mov edx, 0
        div ecx                 ; ut3/u
        call utmslash1
        LDSP
        mov eax, [ebx + WSIZE]
        mov [ebx], eax
        INC_DSP
        mov eax, [ebx + WSIZE]
        mov [ebx], eax
        INC_DSP
        mov eax, [ebx - 17*WSIZE]   ; r7
        mov [ebx], eax
        sub ebx, 3*WSIZE
        mov eax, [ebx - 5*WSIZE]    ; q3
        mov [ebx], eax
        DEC_DSP
        STSP
        DEC_DTSP
        DEC_DTSP
        xor eax, eax
        ret

L_tabs:
; Triple length absolute value (needed by L_stsslashrem, STS/REM)
        LDSP
        INC_DSP
        mov ecx, [ebx]
        mov eax, ecx
        cmp eax, 0
        jl tabs1
        xor eax, eax
        ret
tabs1:
        add ebx, 2*WSIZE
        mov eax, [ebx]
        clc
        sub eax, 1
        not eax
        mov [ebx], eax
        DEC_DSP
        mov eax, [ebx]
        sbb eax, 0
        not eax
        mov [ebx], eax
        mov eax, ecx
        sbb eax, 0
        not eax
        mov [ebx - WSIZE], eax
        xor eax, eax
        ret

L_stsslashrem:
; Divide signed triple length by signed single length to give a
; signed triple quotient and single remainder, according to the
; rule for symmetric division.
        LDSP
        INC_DSP
        mov ecx, [ebx]                 ; divisor in ecx
        cmp ecx, 0
        jz E_div_zero
        mov eax, [ebx + WSIZE]         ; t3
        push eax
        cmp eax, 0
        mov eax, 0
        setl al
        neg eax
        mov edx, eax
        cmp ecx, 0
        mov eax, 0
        setl al
        neg eax
        xor edx, eax                  ; sign of quotient
        push edx
        STSP
        call L_tabs
        sub _GlobalSp, WSIZE
        _ABS
        call L_utsslashmod
        pop edx
        cmp edx, 0
        jz stsslashrem1
        TNEG
stsslashrem1:
        pop eax
        cmp eax, 0
        jz stsslashrem2
        LDSP
        add ebx, 4*WSIZE
        neg D[ebx]
stsslashrem2:
        xor eax, eax
        ret

_L_utmslash:
	; Divide unsigned triple length by unsigned to give ud quotient.
	; A "Divide Overflow" error results if the quotient doesn't fit
	; into a double word
	push ebx  ; Win32 stdcall calling convention 
	LDSP
	mov ecx, [ebx + WSIZE]	; divisor in ecx
	pop ebx
	cmp ecx, 0
	jz E_div_zero
	push ebx
	LDSP
	INC2_DSP
	mov eax, [ebx]	; ut3
	pop ebx
	mov edx, 0
	div ecx		; ut3/u
	cmp eax, 0
	jnz E_div_overflow
utmslash1:
        push ebx
	LDSP
	mov [ebx-4*WSIZE], eax	; q3
	mov [ebx-5*WSIZE], edx	; r3
	INC2_DSP
	INC_DSP
	mov eax, [ebx]		; ut2
	mov edx, 0
	div ecx			; ut2/u
	push ebx
	LDSP
	mov [ebx-2*WSIZE], eax	; q2
	mov [ebx-3*WSIZE], edx	; r2
	pop ebx
	INC_DSP
	mov eax, [ebx]		; ut1
	mov edx, 0
	div ecx			; ut1/u
	push ebx
	LDSP
	mov [ebx], eax		; q1
	mov [ebx-WSIZE], edx	; r1
	mov edx, [ebx-5*WSIZE]	; r3 << 32
	mov eax, 0
	div ecx			; (r3 << 32)/u
	mov [ebx-6*WSIZE], eax	; q4
	mov [ebx-7*WSIZE], edx	; r4
	mov edx, [ebx-3*WSIZE]	; r2 << 32
	mov eax, 0
	div ecx			; (r2 << 32)/u
	mov [ebx-8*WSIZE], eax	; q5
	mov [ebx-9*WSIZE], edx	; r5
	mov edx, [ebx-7*WSIZE]	; r4 << 32
	mov eax, 0
	div ecx			; (r4 << 32)/u
	mov [ebx-10*WSIZE], eax	; q6
	mov [ebx-11*WSIZE], edx	; r6
	mov edx, 0
	mov eax, [ebx-WSIZE]	; r1
	add eax, [ebx-9*WSIZE]	; r1 + r5
	jnc utmslash2
	inc edx
utmslash2:
	add eax, [ebx-11*WSIZE]	; r1 + r5 + r6
	jnc utmslash3
	inc edx
utmslash3:
	div ecx
	mov [ebx-12*WSIZE], eax ; q7
	mov [ebx-13*WSIZE], edx ; r7
	mov edx, 0
	add eax, [ebx-10*WSIZE]	; q7 + q6
	jnc utmslash4
	inc edx
utmslash4:
	add eax, [ebx-8*WSIZE]	; q7 + q6 + q5
	jnc utmslash5
	inc edx
utmslash5:
	add eax, [ebx]		; q7 + q6 + q5 + q1
	jnc utmslash6
	inc edx
utmslash6:
	pop ebx
	mov [ebx], eax
	DEC_DSP
	push ebx
	LDSP
	mov eax, [ebx-2*WSIZE]	; q2
	add eax, [ebx-6*WSIZE]	; q2 + q4
	add eax, edx
	pop ebx
	mov [ebx], eax
	DEC_DSP
	STSP
	INC2_DTSP
	xor eax, eax
	pop ebx  ; Win32 stdcall calling convention
	ret

_L_mstarslash:
	push ebx  ; Win32 stdcall calling convention
	LDSP
	INC_DSP
	INC_DSP
	mov eax, [ebx]
	INC_DSP
	xor eax, [ebx]
	shr eax, 31
	push eax	; keep sign of result -- negative is nonzero
	LDSP
	INC_DSP
	STSP
	INC_DTSP
	_ABS
	LDSP
	INC_DSP
	STSP
	INC_DTSP
	call _L_dabs
	LDSP
	DEC_DSP
	STSP
	DEC_DTSP
	call _L_udmstar
	LDSP
	DEC_DSP
	STSP
	DEC_DTSP
	call _L_utmslash
	pop eax
	cmp eax, 0
	jnz mstarslash_neg
	xor eax, eax
	pop ebx    ; Win32 stdcall calling convention
	ret
mstarslash_neg:
	DNEGATE
	xor eax, eax
	pop ebx    ; Win32 stdcall calling convention
	ret

L_fmslashmod:
        LDSP
        mov eax, WSIZE
        add ebx, eax
        STSP
        mov ecx, [ebx]
	cmp ecx, 0
	jz E_div_zero
        add ebx, eax
        mov edx, [ebx]
        add ebx, eax
        mov eax, [ebx]
        idiv ecx
        mov [ebx], edx
        DEC_DSP
        mov [ebx], eax
	INC_DTSP
	cmp ecx, 0
	jg fmslashmod2
        cmp edx, 0
	jg fmslashmod3
	xor eax, eax
	NEXT
fmslashmod2:
	cmp edx, 0
        jge fmslashmodexit
fmslashmod3:
        dec eax     ; floor the result
        mov [ebx], eax
        INC_DSP
        add [ebx], ecx
fmslashmodexit:
        xor eax, eax
        NEXT

L_smslashrem:
        LDSP
        mov eax, WSIZE
        add ebx, eax
        STSP
        mov ecx, [ebx]
	cmp ecx, 0
	jz E_div_zero
        add ebx, eax
        mov edx, [ebx]
        add ebx, eax
        mov eax, [ebx]
        idiv ecx
        mov [ebx], edx
        DEC_DSP
        mov [ebx], eax
        INC_DTSP
        xor eax, eax
        NEXT

L_stod:
	STOD
	NEXT

L_stof:
        add _GlobalSp, WSIZE
        inc _GlobalTp
        mov ebx, _GlobalSp
        FILD D[ebx]
        mov ebx, _GlobalTp
        mov B[ebx], OP_IVAL
        dec ebx
        mov B[ebx], OP_IVAL
        dec _GlobalTp
        dec _GlobalTp
        mov ebx, _GlobalSp
        sub ebx, WSIZE
        FSTP Q[ebx]
        sub _GlobalSp, 2*WSIZE
        NEXT

L_dtof:
        LDSP
        mov eax, WSIZE
        add ebx, eax
        mov eax, [ebx]
        xchg eax, [ebx + WSIZE]
        mov [ebx], eax
        FILD Q[ebx]
        FSTP Q[ebx]
        xor eax, eax
        NEXT

L_froundtos:
        add _GlobalSp, WSIZE
        mov ebx, _GlobalSp
        FLD Q[ebx]
        add ebx, WSIZE
        FISTP D[ebx]
        inc _GlobalTp
        mov ebx, _GlobalTp
        inc ebx
        mov B[ebx], OP_IVAL
        NEXT

L_ftrunctos:
        LDSP
	mov eax, WSIZE
	add ebx, eax
	STSP
	FLD Q[ebx]
	FNSTCW [ebx]
	mov ecx, [ebx]	; save NDP control word		
	mov edx, ecx
	mov dh, 12
	mov [ebx], edx
	FLDCW [ebx]
	add ebx, eax
	FISTP D[ebx]
	sub ebx, eax
	mov [ebx], ecx
	FLDCW [ebx]		; restore NDP control word
	inc _GlobalTp
	mov ebx, _GlobalTp
	inc ebx
	mov B[ebx], OP_IVAL
	xor eax, eax	
	NEXT
	
L_ftod:
        mov eax, WSIZE
        mov ebx, _GlobalSp
        add ebx, eax
        FLD Q[ebx]
        sub ebx, eax
        FNSTCW [ebx]
        mov ecx, [ebx]  ; save NDP control word
        mov edx, ecx
        mov dh, 12
        mov [ebx], edx
        FLDCW [ebx]
        add ebx, eax
        FISTP Q[ebx]
        sub ebx, eax
        mov [ebx], ecx
        FLDCW [ebx]     ; restore NDP control word
        add ebx, eax
        mov eax, [ebx]
        xchg eax, [ebx + WSIZE]
        mov [ebx], eax
        xor eax, eax
        NEXT

L_degtorad:
        LDSP
        INC_DSP
        FLD Q[ebx]
        FLD Q FCONST_180
        FDIV
        FLDPI
        FMUL
        FSTP Q[ebx]
        NEXT

L_radtodeg:
        LDSP
        INC_DSP
        FLD Q[ebx]
        FLDPI
        FDIV
        FLD Q FCONST_180
        FMUL
        FSTP Q[ebx]
        NEXT

L_fne:
        FREL_DYADIC xor, 64, setnz
        NEXT

L_feq:
        FREL_DYADIC and, 64, setnz
        NEXT

L_flt:
        FREL_DYADIC and, 65, setz
        NEXT

L_fgt:
        FREL_DYADIC and, 1, setnz
        NEXT

L_fle:
        FREL_DYADIC xor, 1, setnz
        NEXT

L_fge:
        FREL_DYADIC and, 65, setnz
        NEXT

L_fzeroeq:
        LDSP
        mov eax, WSIZE
        add ebx, eax
        mov ecx, [ebx]
        STSP
        add ebx, eax
        mov eax, [ebx]
        shl eax, 1
        or eax, ecx
        mov eax, 0
        setz al
        neg eax
        mov [ebx], eax
frelzero:
        mov ebx, _GlobalTp
        inc ebx
        mov _GlobalTp, ebx
        inc ebx
        mov B[ebx], OP_IVAL
        xor eax, eax
        NEXT

L_fzerolt:
        LDSP
        mov eax, WSIZE
        add ebx, eax
        STSP
        FLD Q[ebx]
        add ebx, eax
        FLDZ
        FCOMPP
        FNSTSW ax
        and ah, 69
        mov eax, 0
        setz al
        neg eax
        mov [ebx], eax
        jmp frelzero

L_fzerogt:
        LDSP
        mov eax, WSIZE
        add ebx, eax
        STSP
        FLDZ
        FLD Q[ebx]
        add ebx, eax
        FUCOMPP
        FNSTSW ax
        sahf
        mov eax, 0
        seta al
        neg eax
        mov [ebx], eax
        jmp frelzero

L_fsincos:
        LDSP
        FLD Q[ebx + WSIZE]
        FSINCOS
        FSTP Q[ebx - WSIZE]
        FSTP Q[ebx + WSIZE]
        sub ebx, 2*WSIZE
        STSP
        mov ebx, _GlobalTp
        mov B[ebx], OP_IVAL
        dec ebx
        mov B[ebx], OP_IVAL
        dec ebx
        mov _GlobalTp, ebx
        NEXT

L_fadd:
        LDSP
        mov eax, WSIZE
        add ebx, eax
        FLD Q[ebx]
        sal eax, 1
        add ebx, eax
        FADD Q[ebx]
        FSTP Q[ebx]
        DEC_DSP
        STSP
        INC2_DTSP
        xor eax, eax
        NEXT

L_fsub:
        LDSP
        mov eax, 3*WSIZE
        add ebx, eax
        FLD Q[ebx]
        sub eax, WSIZE
        sub ebx, eax
        FSUB Q[ebx]
        add ebx, eax
        FSTP Q[ebx]
        DEC_DSP
        STSP
        INC2_DTSP
        xor eax, eax
        NEXT

L_fmul:
        LDSP
        mov eax, WSIZE
        add ebx, eax
        FLD Q[ebx]
        add ebx, eax
        mov ecx, ebx
        add ebx, eax
        FMUL Q[ebx]
        FSTP Q[ebx]
        mov ebx, ecx
        STSP
        INC2_DTSP
        xor eax, eax
        NEXT

L_fdiv:
        LDSP
        mov eax, WSIZE
        add ebx, eax
        FLD Q[ebx]
        add ebx, eax
        mov ecx, ebx
        add ebx, eax
        FDIVR Q[ebx]
        FSTP Q[ebx]
        mov ebx, ecx
        STSP
        INC2_DTSP
        xor eax, eax
        NEXT

L_fabs:
        LDSP
        FLD Q[ebx + WSIZE]
        FABS
        FSTP Q[ebx + WSIZE]
        NEXT

L_fneg:
        LDSP
        FLD Q[ebx + WSIZE]
        FCHS
        FSTP Q[ebx + WSIZE]
        NEXT

L_floor:
        LDSP
        INC_DSP
        mov eax, [ebx + WSIZE]
        push ebx
        push eax
        mov eax, [ebx]
        push eax
        call _floor
        add esp, 8
        pop ebx
        FSTP Q[ebx]
        DEC_DSP
        xor eax, eax
        NEXT

L_fround:
        LDSP
        INC_DSP
        FLD Q[ebx]
        FRNDINT
        FSTP Q[ebx]
        DEC_DSP
        NEXT

L_ftrunc:
        LDSP
        INC_DSP
        FLD Q[ebx]
        fnstcw offset NDPcw
        mov ecx, NDPcw          ; save NDP control word
        mov ch, 12
        mov [ebx], ecx
        FLDCW [ebx]
        FRNDINT
        fldcw offset NDPcw      ; restore NDP control word	
        FSTP Q[ebx]
        DEC_DSP
        NEXT

L_fsqrt:
        LDSP
        FLD Q[ebx + WSIZE]
        FSQRT
        FSTP Q[ebx + WSIZE]
        NEXT

L_fcos:
        LDSP
        FLD Q[ebx + WSIZE]
        FCOS
        FSTP Q[ebx + WSIZE]
        NEXT

L_fsin:
        LDSP
        FLD Q[ebx + WSIZE]
        FSIN
        FSTP Q[ebx + WSIZE]
        NEXT

L_fatan2:
        LDSP
        add ebx, 2*WSIZE
        FLD Q[ebx + WSIZE]
        FLD Q[ebx - WSIZE]
        FPATAN
        FSTP Q[ebx + WSIZE]
        STSP
        INC2_DTSP
        NEXT

L_backslash:
        mov ecx, _pTIB
        mov B[ecx], 0
        NEXT

_vm     endp
_TEXT ENDS
end


