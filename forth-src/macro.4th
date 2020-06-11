\ macro.4th
\
\ MACRO wordset from Wil Baden's Tool Belt series in
\ Forth Dimensions (FD) Vol. 19, No. 2, July/August 1997.
\ Original code has been modified by Jabari Zakiya to make 
\ more efficient MACRO which allows insertion of parameters 
\ following the macro. "\" represents place where parameter 
\ is inserted.
\
\ Example:  
\	    MACRO  ??  " IF  \  THEN "
\	    : FOO .. ?? EXIT .... ;  ?? compiles to -- IF EXIT THEN
\
\ Following files required under kForth:
\
\	strings.4th
\	ans-words.4th
\
\ Revisions:
\
\	2003-2-6  kForth version created  KM
\
\ For use with ANS Forths, define the following:
\
\     : ?ALLOT HERE SWAP ALLOT ;
\     : NONDEFERRED ;

: PLACE  ( caddr n addr -)  2DUP  C!  CHAR+  SWAP  CHARS  MOVE ;
: SSTRING ( char "ccc" - addr) WORD COUNT DUP 1+ CHARS ?ALLOT PLACE ;

: split-at-char  ( a  n  char  -  a  k  a+k  n-k)
	>R  2DUP  BEGIN  DUP  WHILE  OVER  C@  R@  -
        ( WHILE  1 /STRING  REPEAT  THEN)
	0= IF R> DROP TUCK 2>R - 2R> EXIT THEN 1 /STRING REPEAT
        R> DROP  TUCK  2>R  -  2R> ;


: DOES>MACRO  \ Compile the macro, including external parameters
	DOES> COUNT  BEGIN [CHAR]  \ split-at-char  2>R  EVALUATE  R@
	WHILE BL WORD COUNT EVALUATE 2R>  1 /STRING REPEAT
	R> DROP  R> DROP ;

: MACRO  CREATE IMMEDIATE  S" NONDEFERRED" EVALUATE  CHAR SSTRING
	DOES>MACRO ;


\ Further examples of macros:
\
\	 macro sum() " \ @ \ @ + ."
\ Use:
\
\	variable a
\	variable b
\	variable c
\	variable d
\
\	: test  sum() a b   sum() c d ;
