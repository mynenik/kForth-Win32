\ utils.4th
\
\ Some handy utilities for kForth
\
\ Requires:
\ 	strings.4th
\

: shell ( a u -- n | execute a shell command) 
        strpck system ;

: ptr ( a <name> -- | create an address constant ) 
        create 1 cells ?allot ! does> a@ ;

: table ( v1 v2 ... vn n <name> -- | create a table of singles ) 
	create dup cells ?allot over 1- cells + swap
	0 ?do dup >r ! r> 1 cells - loop drop ;

: ctable ( ... n <name> -- | create a table of characters/byte values)
    dup >r create ?allot dup r> + 1-
    ?do  i c! -1 +loop ;

: $table ( a1 u1 a2 u2 ... an un n umax <name> -- | create a string table )
	CREATE  2DUP * 1 CELLS + ?allot 2DUP ! 
	  1 CELLS + >R 2DUP SWAP 1- * R> + 
	  SWAP ROT  
	  0 ?DO  
	    2>R  R@  1-  MIN  DUP  2R@  DROP  C!
	    2R@  DROP  1+  SWAP  CMOVE
	    2R>  DUP >R  -  R>
	  LOOP 2DROP
	DOES>  ( n a -- an un) 
	  DUP @ ROT * + 1 CELLS + COUNT ;  	

: pack ( a u a2 -- | copy string to counted string at a2)
	2DUP C! 1+ SWAP CMOVE ;	

: place  ( addr len c-addr -- | copy string to counted string at a2)
     2DUP 2>R
     CHAR+ SWAP CHARS MOVE
     2R> C!
;

: $constant  ( a u -- | create a string constant )
	CREATE  256 ?allot pack
	DOES>   COUNT ;  \ execution: ( -- a' u )
