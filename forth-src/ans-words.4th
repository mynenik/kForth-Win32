\ ans-words.4th
\
\ Some ANS Forth words which are not a part of the intrinsic
\ dictionary of kForth are implemented here in source code.
\ Use with kForth version 1.0.14 or higher.
\
\ Some other words, which are not part of the ANS specification,
\ but which are so commonly used that they are effectively
\ standard Forth words, are also defined here.
\
\ Also, see the following files for the source code definitions 
\ of other ANS Forth words which are not a part of kForth's 
\ dictionary:   
\ 
\     strings.4th 
\     files.4th 
\     ansi.4th 
\     dump.4th
\
\ Copyright (c) 2002--2003 Krishna Myneni, Creative Consulting
\   for Research and Education
\
\ Provided under the GNU General Public License
\
\ Revisions:
\	2002-09-06  Created    km
\       2002-10-27  added F~   km
\	2003-02-15  added D2*, D2/, DMIN, DMAX, 2CONSTANT, 2VARIABLE, 
\			       2LITERAL  km
\	2003-03-02  fixed F~ for case of exact equality test  km
\	2003-03-09  added >NUMBER, DEFER, and IS  km
\       2003-09-28  added [IF], [ELSE], [THEN]  km
BASE @
DECIMAL
\ ============== From the CORE wordset

: SPACE BL EMIT ;
: CHARS ;
: MOVE ( src dest u -- ) 
	>R 2DUP OVER R@ + OVER > -ROT < AND R> SWAP \ is src < dest < src+u ?
	IF CMOVE> ELSE CMOVE THEN ;

: >NUMBER ( ud1 a1 u1 -- ud2 a2 u2 )
    DUP 0 ?DO
      2DUP DROP C@ 
      DUP [CHAR] 9 > IF 223 AND [CHAR] A - 10 + ELSE [CHAR] 0 - THEN
      DUP -1 > OVER BASE @ < AND
      IF -ROT 2>R >R BASE @ 1 M*/ R> S>D D+ 2R>
      ELSE DROP LEAVE THEN
      1- SWAP 1+ SWAP
    LOOP ; 
 


\ ============ From the CORE EXT wordset

CREATE PAD 512 ALLOT

: TO ' >BODY STATE @ IF POSTPONE LITERAL POSTPONE ! ELSE ! THEN ; IMMEDIATE
: VALUE CREATE 1 CELLS ?ALLOT ! DOES> @ ;
: WITHIN  OVER - >R - R> U< ;



\ ============ From the DOUBLE number wordset

\ The following are valid for two's-complement systems such as Intel x86
: D>S  DROP ;
: D2*  2* >R DUP 31 RSHIFT SWAP 2* SWAP R> OR ;
: D2/  DUP 31 LSHIFT SWAP 2/ >R SWAP 1 RSHIFT OR R> ;

: DMIN ( d1 d2 -- d1 | d2) 2OVER 2OVER D< NOT IF 2SWAP THEN 2DROP ;
: DMAX ( d1 d2 -- d1 | d2) 2OVER 2OVER D< IF 2SWAP THEN 2DROP ;

: 2CONSTANT  FCONSTANT ;  \ valid for kForth, not all other ANS Forths
: 2VARIABLE  FVARIABLE ;  \   "                   "
: 2LITERAL   SWAP POSTPONE LITERAL POSTPONE LITERAL ; IMMEDIATE  



\ ============ From the FLOATING EXT wordset

: F~ ( f1 f2 f3 -- flag )
     FDUP 0e F> 
     IF 2>R F- FABS 2R> F<
     ELSE FDUP F0=
       IF FDROP		  \ are f1 and f2 *exactly* equal 
         ( F=)		  \ F= cannot distinguish between -0e and 0e
	 D=
       ELSE FABS 2>R FOVER FABS FOVER FABS F+ 2>R
         F- FABS 2R> 2R> F* F<
       THEN
     THEN ;
 

\ ============ From the PROGRAMMING TOOLS wordset
( see DPANS94, sec. A.15)

: [ELSE]  ( -- )
    1 BEGIN                               \ level
      BEGIN
        BL WORD COUNT  DUP  WHILE         \ level adr len
        2DUP  S" [IF]"  COMPARE 0=
        IF                                \ level adr len
          2DROP 1+                        \ level'
        ELSE                              \ level adr len
          2DUP  S" [ELSE]"
          COMPARE 0= IF                   \ level adr len
             2DROP 1- DUP IF 1+ THEN      \ level'
          ELSE                            \ level adr len
            S" [THEN]"  COMPARE 0= IF     \ level
              1-                          \ level'
            THEN
          THEN
        THEN ?DUP 0=  IF EXIT THEN        \ level'
      REPEAT  2DROP                       \ level
    REFILL 0= UNTIL                       \ level
    DROP
;  IMMEDIATE

: [IF]  ( flag -- )
   0= IF POSTPONE [ELSE] THEN ;  IMMEDIATE

: [THEN]  ( -- )  ;  IMMEDIATE


\ ============= De Facto Standard Words

: DEFER  ( "name" -- )
      CREATE 1 CELLS ?ALLOT ['] ABORT SWAP ! DOES> A@ EXECUTE ;

: IS    ( xt "name" -- )
      '
      STATE @ IF
        postpone LITERAL postpone >BODY postpone !
      ELSE
        >BODY !
      THEN ; IMMEDIATE


BASE !
