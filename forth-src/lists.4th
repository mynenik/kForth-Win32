\ lists.4th
( *
 * LANGUAGE    : ANS Forth with extensions
 * PROJECT     : Forth Environments
 * DESCRIPTION : A Lisp-like List Processor written in Forth
 * CATEGORY    : Experimental Tools
 * AUTHOR      : David Sharp
 * LAST CHANGE : May 22, 1994, Marcel Hendrix, docs, testing. CLEAN-UP crashes!
 * LAST CHANGE : May 21, 1994, Marcel Hendrix, seems ok
 * LAST CHANGE : May 14, 1994, Marcel Hendrix, port
 * EXTENSIVE REVISIONS: March--April 2003, Krishna Myneni
 * )

\ version 1.1a, 2003-04-15
\ Copyright (c) 199? David Sharp, 1994 Marcel Hendrix, and 2003 Krishna Myneni

(  COMMENTS FROM THE ORIGINAL CODE:
\ REVISION -lisp "=== Lisp-like Lists     Version 1.04 ==="

This is not LISP. The vocabulary contains words to define and process lists
of other lists, strings, and numbers. This is done using a model that
resembles LISP. Most notably, LISP functions are absent, because you should
use Forth for that.

The given list-processing tools are very nice, even when you leave out the
'oh boy, a Lisp written in Forth' hype. It could be immediately useful in some
sort of string package, database or AI-tool.

The biggest problem with the code is the garbage collector. It has crashed
on me occasionally. Please let me know if you succeed in making it more robust.
One cause for a crash is when you try to forget a list, that screws up the
administration of the heap and the gc algorithm fails.
A second cause is when you have mixed NEWLIST and SET-TO .
I strongly suspect a stack size / recursion problem for some degenerated
lists.
)

\ Note: The garbage collector code has been removed from this version.  KM 
\
\
\	CONS
\
\ Construct a new list that consists of the old one but additionally has a
\ cell containing ^value in front.
\ e.g. '( adam ) car  '( ape 123 '456 ) ptr hicky
\      hicky cons print --->  ( adam ape #123 456 )
\ or   quote eva  hicky cons print --->  ( eva ape #123 456 )
\
\
\	CAR
\
\ CAR returns the value of the first link in a list. Equivalent to FIRST .
\ e.g. '( ape 123 '456 ) to hicky   hicky car print  ---> ape
\      hicky cdr cdr car print  ---> 456
\
\
\	FIRST
\
\ FIRST returns the value of the first link in a list. Equivalent to CAR .
\ e.g. '( ape 123 '456 ) to hicky   hicky first print  ---> ape
\      hicky rest cdr first print  ---> 456
\
\
\	CDR
\
\ CDR returns the address of the next link in the list.
\ e.g. '( ape 123 '456 ) to hicky  hicky cdr print ---> ( #123 456 )
\      hicky cdr cdr print ---> ( 456 )
\
\
\	REST
\
\ REST returns the address of the next link in the list. Equivalent to CDR .
\ e.g. '( ape 123 '456 ) to hicky  hicky rest print ---> ( #123 456 )
\      hicky rest rest print ---> ( 456 )
\
\
\	SECOND
\
\
\	LAST
\
\ Return the last member of a given list.
\ Example: '( gh ij kz ( ab cd de ]  last print ---> ( ( ab cd de ) )
\
\
\	REVERSE
\
\ Put the elements of the given list in reverse order.
\ The original list is kept intact. The returned list is newly created.
\ Example:  '( one two three ) reverse print ---> ( three two one )
\
\
\	LIST
\
\
\	ATOM$P
\
\ is object an atomic string?
\ Example: quote  456 atom$p . ---> 0
\          quote '456 atom$p . ---> -1
\
\
\	NUMBERP
\
\ "lisp numbers" are stored amongst the lists and are distinguished by
\ having 0 in their cdr slot.
\ Example: quote  456 numberp . ---> -1
\          quote '456 numberp . ---> 0
\
\
\	ATOM or ATOMP
\
\ Is the object an atom$ or a number?
\ Example: quote  456 atomp . ---> -1
\          quote '456 atomp . ---> -1
\          456 atomp . ---> 0
\
\
\	LISTP
\
\ Is address pointing to a list (or nil)?
\ Example: '( 456 ab not ) listp . ---> -1
\          123 listp . ---> 0
\
\
\	DOTP
\
\ Is this list a "dotted" pair?  (Then the cdr slot does not contain a list).
\ Example: '( abc . def ) dotp . ---> -1
\          '( abc   def ) dotp . ---> 0
\
\
\	LATP
\
\ Does the list (top-level) consist only of atoms?
\ Example: '( abc def ) latp . ---> -1
\          '( abc ( de fg hi ) ) latp . ---> 0
\
\
\	LENGTH
\
\ Number of top-level list elements.
\ Example: '( abc ( de fg hi ) ) length . ---> 2
\          '( abc ( de fg hi ) ) cdr car length . ---> 3
\
\
\	#ATOMS
\
\ The total number of constituent atoms in list.
\ Example: '( abc ( de fg hi ) ) #atoms . ---> 4
\
\
\	POSITION
\
\
\	POSITION:TEST
\
\
\	NTH
\
\
\	MEMBER
\
\
\	MEMBER:TEST
\
\
\	NULL  or  NIL?
\
\ Test a list to see if it is the NIL list.
\
\
\	EVERY
\
\
\	SOME
\
\
\	MAPCAR
\
\
\
\	EQ
\
\ The only time two lists will be equal with eq is when they are the same list.
\ Two atoms are equal if they are identical.
\ Example: quote-atom 123  quote-atom 123  equal . ---> -1
\          quote-atom 321  quote-atom 123  equal . ---> 0
\          '( aap noot mies ) '( aap noot mies ) equal . ---> 0
\          '( aap noot mies ) dup equal . ---> -1
\
\
\	EQUAL
\
\ Lisp "equal"
\
\
\	LIST-EQUAL
\
\ Do the lists consist of equivalent atoms?
\ Example: '( aap noot mies ) '( aap noot mies ) list-equal . ---> -1
\
\
\	PLUS
\
\ Model for l-number arithmetic: addition.
\ Example: quote 5  quote 6  plus print ---> #11
\
\
\	ZEROP
\
\ Model for l-number arithmetic: compare for zero.
\ Example: quote 0  zerop . ---> -1
\
\
\	MEMBERP
\
\ Is the expression part of the given list?
\ Example: quote ab  '( gh ij kz ab cd de )  memberp . ---> -1
\          '( ab )  '( gh ij kz ab ( cd de ) )  memberp . ---> 0
\
\
\	COPY-LIST
\
\ Make a fresh copy of a list
\ Example: '( x y z ) ptr l1  l1 copy-list ptr l2  l1 l2 eq . ---> 0
\          l1 print l2 print ---> ( one deux drie ) ( one deux drie )
\
\
\	NCONC
\
\ Append list2 to list1 and return list1.
\ DANGER! when list1 or list2 contains the other and you attempt to
\ traverse the result, there will be infinite recursion.
\ Example: '( Bo has problems ) '( with breathing ) append print
\          ---> ( Bo has problems with breathing )
\
\
\	APPEND
\
\ Append list2 to list1 and return a new list3. Similar to NCONC
\ but does not modify list1.
\ DANGER! when list1 or list2 contains the other and you attempt to
\ traverse the result, there will be infinite recursion.
\
\
\	REMOVE
\
\ Remove all occurances of an atom from the top-level of a list.
\ Returns a new list --- the original list is not modified.
\ Example: quote ab   '( ab bc cd ab ( ab ab ) )  remove print
\          ---> ( bc cd ( ab ab ) )
\
\
\	DELETE
\
\ Remove all occurances of an atom from the top-level of a list.
\ The original list is modified.
\  
\	SUBSTITUTE
\
\
\
\	SUBST
\
\
\
\	QUOTE-LIST
\
\ Create a list.
\ e.g. "quote-list ( snimp ( blaggle ) ( morkle . glork ) ( 22 skid doo )]"
\ "]" closes all right parentheses still open. Other special characters are
\ "@" and ".". "@L1" in the quoted list puts the already defined L1 into the
\ list. "." creates a dotted pair.
\ The above list should print:
\ ( snimp ( blaggle ) ( morkle . glork ) ( #22 skid doo ) )
\
\
\	'(
\
\ Create a list, like QUOTE-LIST , but more convenient.
\ Example: '( ( some ) stuff (( like ) this ) ) print --->
\             ( ( some ) stuff (( like ) this ) )
\
\
\	QUOTE
\
\ Creates a list from a string, if the string starts with "(". Else turns it
\ into an atom.
\ Example: quote ( ( some ) stuff (( like ) this ) ) print --->
\          ( ( some ) stuff (( like ) this ) )
\      or: quote jam print ---> jam
\
\
\	TYPE-LIST
\
\ Type the contents of a list.
\ Example: '( 1 2 ( '123 a ) ) type-list ---> ( #1 #2 ( 123 a ) )
\
\
\	PRINT
\
\ Types the contents of about everything (list or atom$ or number).
\ Example: '( 1 2 ( '123 a ) ) print ---> ( #1 #2 ( 123 a ) )
\          quote ape print ---> ape
\
\
\	.STAT
\
\ Print the statistics of memory usage.
\ e.g. .STAT --->
\      There are 1022 links available.

     
\ ANS Forth definitions of kForth words.
\ Uncomment the following lines if not using kForth
 
\ synonym ptr value
\ : ?allot here swap allot ;
\ : nondeferred ;

: ptr create 1 cells ?allot ! does> a@ ;

: 3dup ( a b c -- a b c a b c ) 2 pick 2 pick 2 pick ;

512 1024 *  CONSTANT HEAPSIZE
CREATE heap HEAPSIZE ALLOT
heap ptr hptr

\ halloc allocates specified number of bytes and returns
\   a *handle*. The address of the allocated region
\   may be fetched from the handle, and the size of the
\   allocated region is obtained from the handle by "size?".

: halloc ( u -- hndl | allocate u bytes in the heap )
    DUP >R hptr SWAP 2 CELLS + OVER + TO hptr
    hptr heap HEAPSIZE + >= ABORT" ERROR: HEAP OVERFLOW!" 
    DUP CELL+ CELL+ OVER ! DUP CELL+ R> SWAP ! ;

: size? ( hndl -- u | return size of region)
    S" CELL+ @" EVALUATE ; IMMEDIATE

\ VOCABULARY LISP
\ ONLY  FORTH ALSO  LISP DEFINITIONS

DECIMAL


\ allocate a section of the heap for the linked lists

  16384 CONSTANT #LINKS       	\ 2-cells*#links must be less than HEAPSIZE
                                \ and, most likely, 2-cells*#links should be
                                \ less than half HEAPSIZE

2 cells CONSTANT LINKSIZE     	\ CDR and CAR - two pointers
      2 CONSTANT PROPERTIES   	\ two property bytes per atom$.

\ ---------------------------------------------------------------

\  NIL is the empty list, e.g  NIL -type ---> nil

\ NIL ( -- list )               \ LISP  "nil"
   0 ptr NIL                    \ see FREE-ALL-LINKS .

\ nil is used to mark the last cell of a list.
\ e.g. '( ape 123 '456 ) set-to hicky  hicky cdr cdr cdr -type ---> nil

: nil? ( list -- flag )                            \ LISP  "null"
        nil = ;

: null  nil = ;	\ same as nil?  for Common Lisp compatibility

#links linksize * halloc        \ This is our heap for links.
     ptr links			\ Rest is for atoms.

\ First link in list of free cells made by free-all-links.

variable  free-links
links ptr link-space	\ address of beginning of link space

(
free-all-links turns the space we allocated for links into one long linked
list, "free-links", which we then use as a reservoir of cells to construct
our own lists. When we are through with a particular cell, it can be
returned to the free links list by "cons-ing" it back to the beginning of
the free list with free-a-cell.
)

: free-all-links ( -- )                 \ LISP  "free-all-links"
        link-space
        #links linksize *   erase       \ init link-heap to 0's
        link-space   #links 1- 0        \ set up loop for all but last cell
        DO
          dup linksize + over !		\ each cell points to next
          linksize +			\ creating one long list of 0's
        LOOP
        ( ^last.cell ) TO nil
        nil  nil         !              \ last cell value is "nil" address
        nil  nil cell+   !              \  and contents
        link-space  free-links ! ;      \ make the first cell the value
                                        \ of free-link list
free-all-links


(
the terms cell, link and node are used pretty much interchangeably.
Let's call a cell a link when we are mainly concerned with its role as
a list member.
)

: free-a-cell ( cell -- )       \ returns "cell" to the free-links list
        free-links a@           \ get the current first cell  of free-links
        OVER !                  \ and have our cell point to it.
        free-links ! ;          \ make cell the first cell of free-links list

: get-a-cell ( -- cell )
        free-links a@           \ get 1st free-link
        DUP nil? ABORT" No more links"
        DUP a@ free-links ! ;   \ and make its cdr the new first free-link



(
 We accumulate atom$'s as strings, allocating out of the heap as we go,
 using "halloc" so that each atom$ has its own distinct "heap handle" which
 will be the string's value in a list.
 " 0 halloc TO atom$" will give us "atom$" as a marker to the 1st atom$
 handle. Note that "atom$ @" also marks the end of link space.
)

0 halloc ptr atom$

\ Allocate space for atom$ and its properties

: $>atom$ ( addr count -- hndl )
	DUP properties + halloc
	DUP >R a@			\ c-addr u 'heap --
	SWAP CMOVE R> ;			\ copy string 

: >$  ( hndl -- c-addr u)
	DUP a@ SWAP size? ;		\ hndl -- c-addr u

: atom$-length  ( hndl -- #characters )
        >$ nip properties - ;


: cons  ( ^val list1 -- list2 ) \ LISP  "cons"
        get-a-cell              \ ^val list cell
        DUP >R   !              \ "list" is now cdr in new cell
        R@ CELL+ !  R> ;

: $cons ( addr list -- list )		\ cons an atom$
	>R COUNT $>atom$ R> cons ;


: quote-atom$ ( "name" -- hndl )	\ Lisp "quote-atom-string"
	bl word count $>atom$ ;

: (quote-number)  ( "numstr" -- list )     \ literal number-atoms go
        bl word string>s                \ into the list space with cdr=0
        0 cons ;

: str>hndl ( ^str -- hndl )
	strbufcpy dup number? 
	if drop nip 0 cons 
	else 
	  2drop count
	  over c@
	  [char] ' = if 1- swap 1+ swap then
	  $>atom$ then ;  
  
: quote-atom    ( "str" -- hndl )       \ LISP  "quote-atom"
        bl word str>hndl ;

: (quote-dot)   ( -- hndl )
        quote-atom 
	bl word drop  \ consume the trailing ')'
;

: car ( list -- ^value )                        \ LISP  "car"
        S" CELL+ a@" EVALUATE ; IMMEDIATE nondeferred


: first ( list -- ^value )                      \ LISP  "first"
        S" CELL+ a@" EVALUATE ; IMMEDIATE nondeferred

: cdr ( list -- list )                          \ LISP  "c-d-r"
        S" a@" EVALUATE ; IMMEDIATE nondeferred

: rest ( list -- list )                         \ Common LISP  "rest"
        S" a@" EVALUATE ; IMMEDIATE nondeferred

: second ( list -- ^value )			\ LISP  "second"
	S" a@ CELL+ a@" EVALUATE ; IMMEDIATE nondeferred 

: reverse  ( list -- reversed-list )    \ LISP  "reverse"
        nil swap
        BEGIN  dup nil? 0=
        WHILE  dup car rot cons swap cdr
        REPEAT drop ;

: atom$p  ( hndle|cell.value -- f )     \ LISP  "atom-string-pee"
	atom$ hptr within ;

: numberp   ( handle|cell.value -- f )  \ LISP  "number-pee"
        dup link-space atom$ a@
         within IF cdr 0=
              ELSE drop false
             THEN ;

: atomp ( hndle|cell.value -- f )       \ LISP  "atom-pee"
        dup atom$p swap
        numberp or ;

: atom atomp ;  \ for consistency with Common Lisp

: listp ( addr -- f )                   \ LISP  "list-pee"
        dup link-space atom$ a@
         within IF cdr 0<>
              ELSE nil?
             THEN ;

: dotp  ( list -- f )                   \ LISP  "dot-pee"
        cdr listp 0= ;

: latp  ( list -- f )                   \ LISP  "lat-pee"
         dup  nil?     IF  drop true  exit  THEN
         dup  listp 0= IF  drop false exit  THEN
         dup car atomp IF  cdr recurse
                     ELSE  drop false
                    THEN ;

: length  ( list -- n )                 \ LISP  "length"
        dup dotp IF drop 1 exit THEN
        0
        BEGIN  over nil? 0=
        WHILE  1+ swap cdr swap
        REPEAT nip ;


: #atoms  ( list -- n )		\ total number of atoms in a list
        0 swap
        dup nil?  IF  drop exit  THEN
        dup atomp IF  drop 1+
                ELSE  dup latp  IF  length + exit  THEN
                      dup   car recurse   rot +
                      swap  cdr recurse   +
               THEN ;


: plus  ( l-num1 l-num2 -- l-num3 )		\ LISP  "plus"
        car swap car + 0 cons ;


: zerop ( l-number -- flag )			\ LISP  "zero-pee"
        car 0= ;



: number-eq ( number.hndl1 number.hndl2 -- flag )
        car swap car = ;

: eq    ( atom1.hndl atom2.hndl -- flag )	\ LISP  "eq"
        2dup = IF 2drop true exit THEN \ same atom or list (or whatever)
        over atom$p                     \ if they are atom$'s then compare
        over atom$p  and                \ their contents, including properties.
           IF >$ rot >$ compare 0= exit \ we could subtract PROPERTIES
        THEN                           \ from counts if they're unimportant.
        over numberp
        over numberp  and
           IF number-eq  exit
        THEN
        2drop false ;

: list-equal    ( list1 list2 -- flag )    \ LISP  "list-equal"
        over nil?  over nil?
        and IF  2drop true exit  THEN  \ two nils?
        2dup = IF 2drop true exit THEN  \ save time if same list
        over car  over car
        eq IF  cdr swap  cdr recurse
         ELSE  over car listp   over car listp
              and IF  car swap  car recurse
                ELSE  2drop false exit
               THEN
        THEN ;

: equal  ( ^val1 ^val2 -- flag )		\ LISP "equal"
	2dup listp swap listp and IF list-equal ELSE eq THEN ;
	

: memberp ( expression list -- flag )		\ LISP  "member-pee"
        dup  nil?   IF 2drop false exit THEN
        2dup car eq IF 2drop true  exit THEN
        cdr recurse ;


: last  ( list -- last.member )			\ LISP  "last"
        dup nil? IF exit THEN
        dup listp 0= abort" LAST : not a list"
        BEGIN  dup cdr nil? 0=
        WHILE  cdr
        REPEAT ;


: nconc ( list1 list2 -- list1 )		\ LISP  "nconc"
        over listp  over listp  and 0= abort" Not a list, can't NCONC"
        dup  nil? IF drop nil cons car exit THEN
        over nil? IF nip ELSE over last ! THEN ;


: copy-list  ( list1 -- list1' )
        dup nil? IF exit THEN
        dup car dup listp if recurse THEN
        swap cdr recurse cons ;


: append ( list1 list2 -- list3 )		\ LISP "append"
        over listp  over listp  and 0= abort" Not a list, can't APPEND"
        dup  nil? IF drop copy-list exit THEN
        over nil? IF nip copy-list exit 
	  ELSE swap copy-list swap nconc
        THEN ;


: remove   ( atom list1 --- list2 )		\ LISP  "remove"
        dup nil? IF nip exit THEN
        dup car 2 pick eq IF  cdr recurse exit  THEN
        dup car -rot cdr recurse cons ;

: delete  ( atom list -- list )			\ LISP "delete"
	dup nil? IF nip exit THEN
	dup >r
	BEGIN
	  dup car 2 pick eq IF  \ atom link
	    dup cdr over linksize cmove
	  ELSE cdr THEN
	  dup nil?
	UNTIL
	2drop r> ;


: _substitute ( ^val1 ^val2 list -- )
        BEGIN  dup nil? 0=
        WHILE  dup car atomp
                   IF 2dup
                      car eq IF  2 pick over cell+ ! THEN
                THEN cdr
        REPEAT drop 2drop ;

: substitute ( ^val1 ^val2 list -- list )		\ LISP "substitute"
        dup listp 0= abort" not a list, can't SUBSTITUTE"
        dup >r _substitute r> ;

: _subst ( ^val1 ^val2 list -- )
        BEGIN  dup nil? 0=
        WHILE  dup car atomp
                   IF 2dup
                      car eq IF  2 pick over cell+ !  THEN
                 ELSE 3dup car recurse
                THEN cdr
        REPEAT drop 2drop ;


: subst ( ^val1 ^val2 list -- list )			\ LISP  "subst"
        dup listp 0= abort" not a list, can't SUBST"
        dup >r _subst r> ;


: position ( ^val1 list -- n | n is -1 if not found)	\ LISP "position"
    dup listp 0= abort" not a list, can't find POSITION"
    0 >r 
    BEGIN dup nil? 0= 
    WHILE dup car atomp
      IF  2dup car eq IF  2drop r> exit  THEN  THEN 
      r> 1+ >r cdr  
    REPEAT
    r> drop 2drop -1 ;

: position:test ( ^val1 list xt -- n | n is nil if found)
    over listp 0= abort" not a list, can't find POSITION"
    0 >r >r
    BEGIN dup nil? 0= 
    WHILE 2dup car r@ execute 
      IF  2drop r> drop r> exit  THEN
      r> r> 1+ >r >r cdr  
    REPEAT
    2r> 2drop 2drop -1 ;
    

: nth ( n list -- ^val )			\ LISP "nth"
    swap 0 ?do cdr loop car ;
            
: list  ( list1  list2 -- list3 )		\ LISP "list"
    swap nil cons swap nil cons append  ;


: member ( ^val list1 -- list2 )		\ LISP "member"
    dup >r position r> swap 
    dup -1 = IF 2drop nil ELSE 0 ?do cdr loop THEN ;

: member:test ( ^val list1 xt -- list2 )  \ LISP "member" with :test function
    over >r position:test r> swap 
    dup -1 = IF 2drop nil ELSE 0 ?do cdr loop THEN ;

: assoc ( -- )
;
    
: subsetp ( list1 list2 -- flag )		\ LISP "subsetp"
	2dup nil? swap nil? and IF 2drop true exit THEN  \ both are nil
	dup nil? IF 2drop false exit THEN
	over nil? IF 2drop true exit THEN  \ nil is a subset of non-empty set
	true >r swap
	BEGIN		\ list2 list1
	  dup nil? 0=
	WHILE
	  over over car swap memberp
	  r> and >r cdr
	REPEAT
	2drop r> ;


: set-difference ( list1 list2 -- list3 )	\ LISP "set-difference"
	dup nil? IF drop copy-list exit THEN
	over nil? IF drop exit THEN
	nil >r swap
	BEGIN		\ list2 list1
	  dup nil? 0=
	WHILE
	  dup car dup >r
	  2 pick memberp
	  IF  r> drop  ELSE  r> r> cons >r THEN cdr
	REPEAT 2drop r> ;


: intersection ( list1 list2 -- list3 )		\ LISP "intersection"
	2dup nil? swap nil? or IF 2drop nil exit THEN
	nil >r
	BEGIN
	  dup nil? 0=
	WHILE
	  dup car dup >r 2 pick memberp
	  IF r> r> cons >r ELSE r> drop THEN
	  cdr
	REPEAT 2drop r> ; 	

: adjoin ( ^val list1 -- list2 )		\ LISP "adjoin"
	 2dup memberp  IF nip ELSE cons THEN ;

: union ( list1 list2 -- list3 )		\ LISP "union"
	dup nil? IF drop copy-list exit THEN
	over nil? IF nip copy-list exit THEN 
	BEGIN		\ list1 list2
	  dup nil? 0=
	WHILE 
	  dup car rot adjoin swap cdr
	REPEAT drop ;


: mapcar ( list1 xt -- list2 )			\  LISP  "mapcar"
    >r nil swap 
    BEGIN dup nil? 0=
    WHILE dup car r@ execute rot cons swap cdr 
    REPEAT drop r> drop reverse
;


: every  ( list xt -- flag )			\ LISP "every"
    >r true swap  \ flag list
    BEGIN dup nil? 0= 
    WHILE dup car r@ execute rot and swap cdr
    REPEAT drop r> drop ;

: some  ( list xt -- flag )			\ LISP "some"
    >r false swap
    BEGIN dup nil? 0=
    WHILE dup car r@ execute rot or swap cdr
    REPEAT drop r> drop ;
 

0 value ]?

\ Create a list.
\ e.g. "quote-list ( snimp ( blaggle ) ( morkle . glork ) ( 22 skid doo )]"
\ "]" closes all right parentheses still open. Other special characters are
\ "@" and ".". "@L1" in the quoted list puts the already defined L1 into the
\ list and the quote character for an atomic string. "." creates a dotted pair.
\ The above list should print:
\ ( snimp ( blaggle ) ( morkle . glork ) ( #22 skid doo ) )

: quote-list    ( -- list )             \ LISP  "quote-list"
	false to  ]?
	nil
	begin
	  bl word dup count	\ list ^str a u 
	  if
\ OVER COUNT TYPE CR
	    c@ case		\ list ^str char
	      [char] (  of  drop recurse swap cons false  endof
	      [char] )  of  drop true                     endof
	      [char] ]  of  drop true dup to ]?           endof
              [char] .  of  drop (quote-dot) over ! true  endof
              [char] @  of  count 1- swap 1+ swap strpck find
                            IF >body a@ ELSE drop nil THEN
                            swap cons false               endof
	      [char] "  of  drop postpone s" strpck str>hndl
	                    swap cons false	          endof
	      >r  str>hndl swap cons false r>
	    endcase
	    ]? if drop true then
	  else
	    2drop true
	  then
	until
	dup dotp 0= if reverse then ;


: '(    ( -- list )             \ LISP  "quote-list"
        quote-list ;


: quote ( "str" -- list|^val )            \ LISP  "quote"
        bl word dup count
	IF  
	  c@ case 
	    [char] (  of  drop quote-list  endof
	    [char] "  of  drop postpone s" strpck str>hndl endof
	    >r  str>hndl  r>
	  endcase 
	ELSE drop THEN ;

: make-non-atomic-list ( ^val1 ^val2 ... ^valn  n -- list )
    nil swap 0 ?do cons loop ;

: make-token-list ( a u -- list | make a flat list of tokens from a string )
	nil >r 
	begin  parse_token dup
	while  strpck str>hndl r> cons >r	  
	repeat
	2drop 2drop r> reverse ;


: type-atom$    ( hndl -- )             \ display atom$
        >$ properties - type ;

: (type-car)    ( list -- )             \ display car of list
        dup nil? if drop exit THEN
        car dup numberp IF ." #" car .  \ type literal number
                      ELSE type-atom$ space
                     THEN ;

: _type-list    ( list -- )             \ the recursive part of TYPE-LIST
        dup nil? IF drop exit THEN
        dup car listp
        IF  dup car nil? 
	  IF ." nil "
          ELSE ." ( " dup car recurse ." ) "
          THEN
        ELSE  dup (type-car)
        THEN
        cdr dup atomp
	IF ." . " dup numberp	\ "dotted pairs"
	  IF ." #" cell+ @ . ELSE type-atom$ space THEN
	ELSE recurse 
	THEN ;


: type-list     ( list -- )             \ LISP  "type-list"
        dup listp 0= IF ." not a list "  drop exit THEN
        dup  nil?    IF ." nil"          drop exit THEN
        ." ( " _type-list  ." )" ;



: -type  ( expression -- )              \ LISP  "dash-type"
        dup numberp IF  ." #" car .     \ type literal number
                  ELSE dup listp
                             IF  type-list
                           ELSE  dup atom$p
                                     IF type-atom$
                                   ELSE ." ??"
                                  THEN
                          THEN
                 THEN ;

: print ( expression -- ) -type ;

: .stat ( -- )
     cr ." There are " free-links length 5 .r ."  links available."
     cr heap HEAPSIZE + hptr - 6 .r 
     ."  bytes are available for storing atoms." cr ;   

