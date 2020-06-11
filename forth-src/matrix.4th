\
\ matrix.4th
\ 
\ Integer and floating point matrix manipulation routines for kForth
\ 
\ Copyright (c) 1998--2001 Krishna Myneni
\
\ Revisions: 
\
\	12-29-1998
\	3-29-1999   added rc>frc KM
\	12-25-1999  updated  KM
\	05-10-2000  fixed determ for singular matrix  KM
\	05-17-2000  added defining words for matrices  KM
\	08-10-2001  improved efficiency of several matrix words; 
\	              about 10% faster execution in real apps  KM
\ Notes:
\
\   Usage: 
\	n m matrix name 
\	n m fmatrix name
\
\   Examples: 
\
\	3 5 matrix alpha 	( create a 3 by 5 integer matrix called alpha )
\	3 3 fmatrix beta	( create a 3 by 3 floating pt matrix, beta )

\ Memory storage format for matrices:
\   The first four bytes contains ncols and the next four bytes contains
\   nrows. The matrix data is stored next in row order.
\
\ Indexing Convention:
\	Top left element is 1, 1
\	Bottom right element is nrows, ncols
\
\ matinv and determ are based on routines from P.R. Bevington,
\   "Data Reduction and Error Analysis for the Physical Sciences".
\

: rc_index ( n -- rc | generate an rc with a running index 1 to n )
	dup 1+ 1 do i swap loop ;

: rc_neg ( rc1 -- rc2 | negate the values in the rc )
	sp@ cell+ over 0 do dup @ negate over ! cell+ loop drop ;

: rc_dup ( rc -- rc rc | duplicate an rc on the stack )
	dup 1+ dup 0 do dup pick swap loop drop ;

: rc_max ( rc -- n | find max value in rc )
	1- dup 0> if 0 do max loop else drop then ;

: rc_min ( rc -- n | find min value in rc )
	1- dup 0> if 0 do min loop else drop then ;

: frc_index ( n -- frc | generate fp running index )
	dup 1+ 1 do i s>f rot loop ;

: frc_neg ( frc1 -- frc2 | negate the values in the frc )
	sp@ cell+ over 0 do dup dup f@ fnegate rot f! dfloat+ loop drop ;

: frc_dup ( frc -- frc frc | duplicate an frc on the stack )
	dup 2* 1+ dup 0 do dup pick swap loop drop ; 
 
: frc_max ( frc -- f | find max value in frc )
	1- dup 0> if 0 do fmax loop else drop then ;

: frc_min ( frc -- f | find min value in frc )
	1- dup 0> if 0 do fmin loop else drop then ;

: rc>frc ( rc -- frc | convert integer rc to fp rc )            
	dup 0 do dup i + roll s>f rot loop ;
                 
: mat_size@ ( a -- nrows ncols | gets the matrix size )
	dup cell+ @ swap @ ;

: mat_size! ( nrows ncols a -- | set up the matrix size )
	dup >r ! r> cell+ ! ;

: mat_addr ( i j a -- a2 | returns address of the i j element of a )
	>r cells swap 1- r@ @ * cells + cell+ r> + ;

: mat@ ( i j a -- n | returns the i j element of a )
	mat_addr @ ;

: mat! ( n i j a -- | store n as the i j element of a )
	mat_addr ! ;

: mat_zero ( a -- | zero all entries in matrix )
	dup mat_size@ * >r 1 1 rot mat_addr r>
	0 do 0 over ! cell+ loop drop ; 
	
: row@ ( i a -- rc | fetch row i onto the stack as an rc )
	dup @ >r 1 swap mat_addr r> dup 
	0 do over @ -rot swap cell+ swap loop nip ;

: row! ( rc i a -- | store rc as row i of matrix a )
	dup @ dup >r swap mat_addr r>
	0 do rot over ! 4 - loop 2drop ;

: col@ ( j a -- rc | fetch column j onto the stack as an rc )
	dup mat_size@ cells 2>r 1 -rot mat_addr 2r> 
	swap dup >r 
	0 do over @ -rot swap over + swap loop 2drop r> ;

: col! ( rc j a -- | store rc as column j of matrix a )
	dup mat_size@ cells >r dup >r -rot mat_addr r> r>
	swap 
	0 do >r rot over ! r@ - r> loop 2drop drop ;

: row_swap ( i j a -- | swap rows i and j of matrix a )
	tuck 2dup 2>r 2over 2>r
	2>r row@ 2r> row@
	2r> row! 2r> row! ;

: col_swap ( i j a -- | swap columns i and j of matrix a )
	tuck 2dup 2>r 2over 2>r
	2>r col@ 2r> col@
	2r> col! 2r> col! ; 
	  
: mat. ( a -- | print out the matrix )
	dup mat_size@ 1+
	swap 1+ 1 do dup 1 do over j i rot mat@ . 9 emit loop cr loop
	2drop ;

: fmat_addr ( i j a -- a2 | returns address of the i j element of a )
	>r dfloats swap 1- r@ @ * dfloats + r> + ;

: fmat@ ( i j a -- f | returns the i j element of a )
	fmat_addr f@ ;

: fmat! ( f i j a -- | store f as the i j element of a )
	fmat_addr f! ; 

: fmat_zero ( a -- | zero all entries in fp matrix )
	dup mat_size@ * >r 1 1 rot fmat_addr r>
	0 do dup 0e rot f! dfloat+ loop drop ; 

: frow@ ( i a -- frc | fetch row i of fp matrix a as an frc )
	dup @ >r 1 swap fmat_addr r> dup
	0 do over f@ 2swap swap dfloat+ swap loop nip ;

: fcol@ ( j a -- frc | fetch column j of fp matrix a )
	dup mat_size@ dfloats 2>r 1 -rot fmat_addr 2r>
	swap dup >r
	0 do over f@ 2swap swap over + swap loop 2drop r> ;

: frow! ( frc i a -- | store frc as row i of fp matrix a )
	dup @ dup >r swap fmat_addr r>
	0 do 2swap rot dup >r f! r> 8 - loop 2drop ;	

: fcol! ( frc j a -- | store frc as column j of fp matrix a )
	dup mat_size@ dfloats >r dup >r -rot fmat_addr r> r>
	swap
	0 do >r 2swap rot dup >r f! r> r@ - r> loop 2drop drop ; 

: frow_swap ( i j a -- | interchange rows i and j for fp matrix a )
	tuck 2dup 2>r 2over 2>r
	2>r frow@ 2r> frow@
	2r> frow! 2r> frow! ;

: fcol_swap ( i j a -- | interchange columns i and j for a )
	tuck 2dup 2>r 2over 2>r
	2>r fcol@ 2r> fcol@
	2r> fcol! 2r> fcol! ; 
	
: fmat. ( a -- | print out the fp matrix )
	dup mat_size@ 1+
	swap 1+
	1 do
	  dup
	  1 do
	    over j i rot fmat@ f. 9 emit 
	  loop
	  cr
	loop
	2drop
;

\ Defining words for matrices

: matrix ( nrows ncols -- | allocate space and initialize size )
	create 2dup * cells 8 + ?allot mat_size! ;

: fmatrix ( nrows ncols -- | allocate space for fp matrix and initialize size )
	create 2dup * dfloats 8 + ?allot mat_size! ;



variable k
variable norder		\ holds order of matrix for matinv
variable arr		\ holds address of array for matinv
fvariable det

\ Calculate the determinant of a sqaure floating pt matrix
\ Destroys the input matrix

: determ ( a -- fdet | a is the matrix )
	dup arr !
	mat_size@ norder ! drop	
	1e det f!
	
	norder @ 0 do
	  i 1+ dup arr a@ fmat@
	  f0= if
	    \ Find next element in row which is non-zero
	    i 1+ 
	    norder @ < if
	     i 1+ dup 1+
	      begin
	        2dup arr a@ fmat@
	        f0= 
	        over norder @ < and
	      while
	        1+
	      repeat
	      2dup arr a@ fmat@
	      f0= if
	        2drop 0e fdup det f!
	        unloop exit
	      then
	      nip
	      norder @ i do
	        i 1+ over arr a@ fmat@
	        i 1+ j 1+ arr a@ fmat@
	        i 1+ 5 pick arr a@ fmat!
	        i 1+ j 1+ arr a@ fmat!
	      loop
	      drop
	      det f@ fnegate det f!
	    else
	      0e fdup det f! unloop exit
	    then
	  then

\ Subtract row k from lower rows to get diagonal matrix

	  i 1+ dup arr a@ fmat@ det f@ f* det f!

	  i 1+ dup k !
	  norder @ <
	  if
	    norder @ i 1+ do
	      norder @ j 1+ do
	        j 1+ i 1+ arr a@ fmat@
	        j 1+ k @ arr a@ fmat@
	        k @ i 1+ arr a@ fmat@
	        k @ dup arr a@ fmat@
	        f/ f* f-
	        j 1+ i 1+ arr a@ fmat!
	      loop
	    loop
	  then
	loop

	det f@
;



fvariable amax

create ik 12 cells allot
create jk 12 cells allot


\ matinv computes the inverse of a symmetric matrix and returns its determinant
\ The input matrix is replaced by its inverse

: matinv ( a  -- fdet )
    dup arr !
    @ dup 
    norder ! dup 1 ik mat_size! 1 jk mat_size!
    1e det f!

    norder @ 0 do

\ Find largest element in rest of matrix

      0e amax f!
      i 1+ k !
      begin
        begin
          norder @ 1+ k @ do
            norder @ 1+ k @ do
	      j i arr a@ fmat@ 
	      fdup fabs amax f@ fabs
	      f>= if
	        amax f!
	        j k @ 1 ik mat!
	        i k @ 1 jk mat! 
	      else
                fdrop
	      then
            loop
         loop  

\ Interchange rows and columns to put amax on diagonal

         amax f@ 
	 f0= if 0e fdup det f! exit then

         k @ 1 ik mat@
         k @
         >=
       until

       k @ 1 ik mat@ k @ 
       > if
	 k @ arr a@ frow@ frc_neg
	 k @ 1 ik mat@ arr a@ frow@
	 k @ arr a@ frow!
	 k @ 1 ik mat@ arr a@ frow!
       then

       k @ 1 jk mat@ k @
       >=
     until

     k @ 1 jk mat@ k @
     > if
       k @ arr a@ fcol@ frc_neg
       k @ 1 jk mat@ arr a@ fcol@
       k @ arr a@ fcol!
       k @ 1 jk mat@ arr a@ fcol!
     then

\ Accumulate elements of inverse matrix

     norder @ 1+ 1 do
       i k @ <> 
       if
         i k @ arr a@ fmat@ fnegate amax f@ f/
	 i k @ arr a@ fmat!
       then
     loop

     norder @ 1+ 1 do
       norder @ 1+ 1 do
         j k @ 
         <> if
           i k @
           <> if
             k @ i arr a@ fmat@
             j k @ arr a@ fmat@
             f*
             j i arr a@ fmat@ f+
	     j i arr a@ fmat!
           then
         then
       loop
     loop

     norder @ 1+ 1 do
       i k @
       <> if
         k @ i arr a@ fmat@ amax f@ f/
         k @ i arr a@ fmat!
       then
     loop

     1e amax f@ f/ k @ dup arr a@ fmat!
     det f@ amax f@ f* det f!

   loop

\ Restore ordering of matrix

   norder @ 0 do
     norder @ i - k !
     k @ 1 ik mat@ k @ 
     > if
       k @ arr a@ fcol@
       k @ 1 ik mat@ arr a@ fcol@ frc_neg
       k @ arr a@ fcol!
       k @ 1 ik mat@ arr a@ fcol!
     then
     k @ 1 jk mat@ k @
     > if
       k @ arr a@ frow@
       k @ 1 jk mat@ arr a@ frow@ frc_neg
       k @ arr a@ frow!
       k @ 1 ik mat@ arr a@ frow!
     then
   loop

   det f@	 
;     	   













