\ ANS Forth Complex Arithmetic Lexicon

\ ---------------------------------------------------
\     (c) Copyright 1998  Julian V. Noble.          \
\       Permission is granted by the author to      \
\       use this software for any application pro-  \
\       vided this copyright notice is preserved.   \
\ ---------------------------------------------------
\
\ Modifications for use with kForth (Rls 2-10-2002 or later)
\   by Krishna Myneni, 03-05-2002.
\
\ Environmental dependences:
\       1. requires FLOAT and FLOAT EXT wordsets
\
\ xxxx  2. assumes separate floating point stack   xxxxxxx
\    THIS VERSION ASSUMES INTEGRATED FP AND DATA STACK ( km)
\
\       3. does not construct a separate complex number stack

\ Complex numbers x+iy are stored on the stack as ( x y -- ).
\ Angles are in radians.
\ Polar representation measures angle from the positive x-axis.

\ All Standard words are in uppercase, non-Standard words in lowercase,
\ as a convenience to the user.

\ Standard words not implemented in kForth, so we provide
\   equivalent defs.
\
\ Added n. as alternative output for complex numbers  km 2003-2-19

: SPACE BL EMIT ;
: FSINCOS ( f -- fsin fcos ) FDUP FSIN FSWAP FCOS ;
: FLOAT+ DFLOAT+ ;
: FLOATS DFLOATS ;
: F2/ 2e F/ ;
: F2* 2e F* ;

\ ---------------------------------------- LOAD, STORE
: z@  DUP  F@  ROT FLOAT+  F@ ;     ( adr -- z)
: z!  DUP  >R FLOAT+  F!  R> F! ;   ( f adr -- z)
\ ------------------------------------ END LOAD, STORE

\ non-Standard fp words I have found useful ( jvn)

: f-rot    FROT  FROT  ;
: fnip   FSWAP  FDROP  ;
: ftuck    FSWAP  FOVER ;

1.0E0  FCONSTANT  f1.0

: 1/f   F1.0  FSWAP  F/ ;
: f^2   FDUP  F*  ;

3.1415926535897932385E0  FCONSTANT  fpi
0.0E0  FCONSTANT  f0.0


\ --------------------------------- MANIPULATE FPSTACK
: z.   FSWAP  F. ."  + i " F. ;  ( x y --)     \ emit complex #

: n. ( x y -- | print complex number in easier to read, more natural form)
	FSWAP FDUP F0= DUP >R IF FDROP ELSE F. THEN
	FDUP F0= IF 
	  R> IF [CHAR] 0 EMIT THEN FDROP EXIT 
	THEN
	FDUP F0< IF 
	  [CHAR] - EMIT R> INVERT IF SPACE THEN
	ELSE 
	  R> INVERT IF [CHAR] + EMIT SPACE THEN
	THEN 
	[CHAR] i EMIT
	FABS FDUP 1E F<> IF SPACE F. ELSE FDROP THEN ;
  

: z=0  f0.0 f0.0 ;                 ( -- 0 0)
: z=1  f1.0 f0.0 ;                 ( -- 1 0)
: z=i  z=1 FSWAP ;                 ( -- 0 1)
: zdrop  FDROP FDROP ;             ( x y --)
: zdup   FOVER FOVER ;             ( x y -- x y x y)

\ temporary storage for stuff from stack

CREATE noname   2 FLOATS  ALLOT     \ ALLOT z variable

: zswap    ( x y u v -- u v x y)
    [ noname ] LITERAL  F!  f-rot
    [ noname ] LITERAL  F@  f-rot  ;

: zover     ( x y u v -- x y u v x y )
    FROT    [ noname FLOAT+ ]  LITERAL  F!   ( -- x u v)
    FROT FDUP   [ noname    ]  LITERAL  F!   ( -- u v x)
    f-rot   [ noname FLOAT+ ]  LITERAL  F@   ( -- x u v y)
    f-rot   [ noname        ]  LITERAL  z@   ( -- x y u v x y)
;

: real    FDROP ;
: imag    fnip  ;
: conjg   FNEGATE ;


: znip     zswap  zdrop ;
: ztuck    zswap  zover ;

: z*f      ( x y a -- x*a y*a)
    FROT  FOVER  F*  f-rot  F*  ;

: z/f      ( x y a -- x/a y/a)
    1/f   z*f  ;

: z*    ( x y u v -- x*u-y*v  x*v+y*u)
\ uses the algorithm
\       (x+iy)*(u+iv) = [(x+y)*u - y*(u+v)] + i[(x+y)*u + x*(v-u)]
\       requiring 3 multiplications and 5 additions
  
        zdup F+                         ( x y u v u+v)
        [ noname ] LITERAL  F!          ( x y u v)
        FOVER F-                        ( x y u v-u)
        [ noname FLOAT+ ] LITERAL F!    ( x y u)
        FROT FDUP                       ( y u x x)
        [ noname FLOAT+ ] LITERAL F@    ( y u x x v-u)
        F*
        [ noname FLOAT+ ] LITERAL F!    ( y u x)
        FROT FDUP                       ( u x y y)
        [ noname ] LITERAL F@           ( u x y y u+v)
        F*
        [ noname ] LITERAL F!           ( u x y)
        F+  F* FDUP                     ( u*[x+y] u*[x+y])
        [ noname ] LITERAL F@ F-        ( u*[x+y] x*u-y*v)
        FSWAP
        [ noname FLOAT+ ] LITERAL F@    ( x*u-y*v u*[x+y] x*[v-u])
        F+ ;                            ( x*u-y*v x*v+y*u)

: z+   FROT F+  f-rot F+ FSWAP ;  ( a b x y -- a+x b+y)

: znegate  FSWAP FNEGATE FSWAP FNEGATE ;

: z-  znegate  z+ ;

: |z|^2   f^2  FSWAP  f^2  F+  ;  ( z -- f)

\ writing |z| and 1/z as shown reduces overflow probability
: |z|   ( x y -- |z|)
    FABS  FSWAP  FABS
    zdup  FMAX  f-rot  FMIN     ( max min)
    FOVER  F/  f^2  1e0  F+  FSQRT  F*  ;

: 1/z   fnegate  zdup  |z|  1/f  FDUP  [ noname ] LITERAL F!
        z*f  [ noname ] LITERAL  F@  z*f  ;

: z/    1/z  z* ;
: z2/   F2/  FSWAP  F2/  FSWAP  ;
: z2*   F2*  FSWAP  F2*  FSWAP  ;

: arg   ( x y -- arg[x+iy] )
        FDUP  F0<  >R FSWAP    
        FATAN2
        R> IF  fpi F2*  F+  THEN ;
\ tested September 27th, 1998 - 21:15

: >polar  ( x+iy -- r phi )  zdup  |z|  f-rot  arg  ;
: polar>  ( r phi -- x+iy )  FSINCOS FROT  z*f   FSWAP  ;

: i*      FNEGATE FSWAP ;  ( x+iy -- -y+ix)
: (-i)*   FSWAP FNEGATE ;  ( x+iy -- y-ix)

: zln   >polar   FSWAP  FDUP  F0=  ABORT" Can't take ZLN of 0"  FLN   FSWAP ;

: zexp   ( z -- exp[z] )   FSINCOS  FSWAP FROT  FEXP  z*f ;

: z^2   zdup  z*  ;
: z^3   zdup  z^2  z* ;
: z^4   z^2  z^2  ;

: z^n      ( z n -- z^n )    \ raise z to integer power
       >R  z=1   zswap  R>
       DUP  50 < IF
         BEGIN   DUP  0>  WHILE  >R
                 R@  1 AND   IF ztuck  z*  zswap THEN z^2
                 R>  2/
         REPEAT  DROP  zdrop 
       ELSE  >R  zln  R>  S>F  z*f  zexp  THEN  ;

: z^   ( x y u v --  [x+iy]^[u+iv] )  zswap zln  z* zexp  ;

: zsqrt   ( x y -- a b )     \ (a+ib)^2 = x+iy
     zdup                               ( -- z z)
     |z|^2                              ( -- z |z|^2 )
     FDUP  F0=   IF   FDROP EXIT  THEN  ( -- z=0 )
     FSQRT FROT  FROT  F0<  >R          ( -- |z| x )  ( -- sgn[y])
     ftuck                              ( -- x |z| x )
     F-  F2/                            ( -- x [|z|-x]/2 )
     ftuck  F+                          ( -- [|z|-x]/2 [|z|+x]/2 )
     FSQRT  R>  IF  FNEGATE  THEN       ( -- [|z|-x]/2  a )
     FSWAP  FSQRT   ;                   ( -- a b)
\ tested September 16th, 1999 - 13:49

\ Complex trigonometric functions
: zcosh    ( z -- cosh[z] )  zexp   zdup   1/z   z+  z2/  ;
: zsinh    ( z -- sinh[z] )  zexp   zdup   1/z   z-  z2/  ;
: ztanh    zexp  z^2    i*   zdup   f1.0 F-   zswap   f1.0 F+   z/  ;
: zcoth    ztanh  1/z ;
: zcos     ( z -- cos[z] )   i*    zcosh  ;
: zsin     ( z -- sin[z] )   i*    zsinh  (-i)* ;
: ztan     ( z -- tan[z] )   i*    ztanh  (-i)* ;

\ Complex inverse trigonometric functions
\   -- after Abramowitz & Stegun, p. 80-81

\ the following is a primitive ANS-compatible data hiding mechanism
\ ( not supported in kForth, so this part is rewritten without compile! )

\ : compile!  ( xt -- )   COMPILE,  ;  IMMEDIATE

: noname ( A|B)   ( x y f1 -- f2)   FROT  F+  |z|  F2/   ;

: alpha.beta  ( x y -- alpha beta)
        zdup  f1.0          noname
        f-rot f1.0 FNEGATE  noname
        zdup  F+  f-rot  F-  ;

( ' NOOP  TO noname)      \ forget hidden xt

\ Note: the following functions have not yet been fully tested. Use
\       with caution!   September 17th, 1999 - 18:14

( Inverse trig functions commented out until verified -- km 03-05-2002)

\ : zasin   alpha.beta   FASIN  FSWAP  FDUP  f^2 f1.0 F-  FSQRT  F+  FLN ;
\ : zacos   alpha.beta   FACOS  FSWAP  FDUP  f^2 f1.0 F-
\          FSQRT  F+  FLN  FNEGATE ;
\ : zatan   zdup  FOVER  |z|^2  FNEGATE f1.0 F+  F/ F2*  FATAN  F2/  f-rot
\          FSWAP  f^2  FOVER  f1.0 F+ f^2  ( f: -- re y x^2 [y+1]^2 )
\          F+  FDUP  FROT  F2*  F-  F/  FLN  F2/ F2/ ;
\ : zasinh  i*   zasin  (-i)* ;
\ : zacosh  zacos  i*   ;
\ : zatanh  i*   zatan  (-i)* ;


\ ------------------------------------------ for use with ftran2xx.f
: zvariable   CREATE   2 FLOATS  ALLOT  ;

: cmplx   ( x 0 y 0 -- x y)  FDROP  FNIP  ;
\ ------------------------------------------

( zconstant  added by km 2-26-2002)

: zconstant   FSWAP  CREATE  2 FLOATS  ?allot  
	      >R  R@  F!  R>  FLOAT+  F!  
	      DOES>  >R  R@  F@  R>  FLOAT+  F@  ;

	         


\ Rudimentary testing: ( answers verified by hand calculation -- km)
\
\ 	zvariable c1		( define complex variable c1)
\	1e 0e c1 z!		( store 1+i0 in c1)
\	z=1 c1 z!		( equivalent to previous line)
\	c1 z@ z.		( prints 1 + i 0)
\
\	2e 3e c1 z!		( store 2+i3 in c1)
\	c1 z@ conjg z.		( 2 + i -3)
\	c1 z@ znegate z.	( -2 + i -3)
\	c1 z@ i* z.		( -3 + i 2)
\	c1 z@ (-i)* z.		( 3 + i -2)
\	c1 z@ z^2 z.		( -5 + i 12) 
\	c1 z@ zsqrt z.		( 1.67415 + i 0.895977)
\	c1 z@ |z|^2 f.		( 13)
\	c1 z@ |z| f.		( 3.60555)
\	c1 z@ 7 z^n z.		( 6554 + i 4449)
\	c1 z@ 2e z*f z.		( 4 + i 6)
\	c1 z@ 2e z/f z.		( 1 + i 1.5)
\	c1 z@ 1/z z.		( 0.153846 + i -0.230769)
\	c1 z@ arg f.		( 0.982794)
\	c1 z@ >polar f. f.	( 0.982794 3.60555)
\	c1 z@ >polar polar> z.	( 2 + i 3)
\	c1 z@ zexp z.		( -7.31511 + i 1.04274)
\	c1 z@ zln z.		( 1.28247 + i 0.982794)
\
\	zvariable c2		
\	2e 3e c1 z!		
\	1e 5e c2 z!		
\	c1 z@ c2 z@ z+ z.	( add c1 and c2, prints 3 + i 8)
\	c1 z@ c2 z@ z- z.	( 1 + i -2)
\	c1 z@ c2 z@ z* z.	( -13 + i 13)
\	c1 z@ c2 z@ z/ z.	( 0.653846 + i -0.269231)
\

