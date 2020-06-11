\ test-lists.4th
\
\ Demonstration of basic list manipulation facilities provided by lists.4th.
\
\ Copyright (c) 2003 Creative Consulting for Research and Education
\ Provided under the GNU General Public License.
\
\ Revisions:
\
\	2003-04-14  km
\
\ Notes:
\
\ 1. Some simple examples are borrowed from P. Norvig's,
\    "Paradigms of Artificial Intelligence Programming:
\     Case Studies in Common Lisp"
\
\ 2. Some list functions are not exemplified here.
\

include ans-words
include strings
include lists

nil  ptr  x
nil  ptr  y
nil  ptr  z

\ Defining lists

'( a b c )  to  x
'( 1 2 3 )  to  y
'( @x @y )  to  z

x  print		     \ =>       ( a b c ) ok
y  print		     \ =>	( #1 #2 #3 ) ok
z  print		     \ =>	( ( a b c ) ( #1 #2 #3 ) ) ok


\ Demonstrate list element retrieval

x  first  print		     \ =>	a ok
x  car    print		     \ =>	a ok
x  rest   print		     \ =>	( b c ) ok
x  cdr    print		     \ =>	( b c ) ok
x  second print		     \ =>	b ok
x  last   print		     \ =>	( c ) ok

\ List Properties

x  length .		     \ =>	3  ok
x  #atoms .		     \ =>	3  ok
z  length .		     \ =>	2  ok
z  #atoms .		     \ =>	6  ok

x  reverse  print	     \ =>	( c b a ) ok
x  print		     \ =>	( a b c ) ok
quote 0  y cons print	     \ =>	( #0 #1 #2 #3 ) ok


\ Some predicate functions

nil  null  .		     \ =>	-1  ok
x  null  .		     \ =>	0  ok
x  listp  .		     \ =>	-1  ok
quote 3  listp  .	     \ =>	0  ok
quote 3  atomp  .	     \ =>	-1  ok
quote 3  numberp  .	     \ =>	-1  ok
quote a  numberp  .	     \ =>	0  ok
quote a  atomp  .	     \ =>	-1  ok
z  car  listp  .	     \ =>	-1  ok
x  car  listp  .	     \ =>	0  ok	     


\ Equality operators

x x  eq .		     \ =>	-1  ok
x y  eq .		     \ =>	0  ok
'( a b c )  x  eq .	     \ =>	0  ok
'( a b c )  x  equal .	     \ =>	-1  ok
quote a  x car  eq .	     \ =>	-1  ok 

quote 2 y  member  print     \ =>	( #2 #3 ) ok
2 x  nth   print	     \ =>	c ok
quote c x  position .	     \ =>	2  ok
quote d x  position .	     \ =>	-1  ok


\ List element removal, deletion, substitution

quote 2 y  remove  print     \ =>	( #1 #3 ) ok
y  print		     \ =>	( #1 #2 #3 ) ok

quote 4 quote 2 y substitute print  \ => ( #1 #4 #3 ) ok

: negate-number ( ^val1 -- ^val2 )
    dup numberp if car negate 0 cons then ;

y ' negate-number mapcar  print     \ => ( #-1 #-4 #-3 ) ok

quote -4 y  delete  print	    \ => ( #-1 #-3 ) ok
y  print			    \ => ( #-1 #-3 ) ok


\ Demonstrate construction of lists from other lists
 
nil  ptr  r
nil  ptr  s

'( a b c d e )  to  r
'( f g h )  to  s


r s  cons    print	     \ =>	( ( a b c d e ) f g h ) ok
r s  list    print	     \ =>	( ( a b c d e ) ( f g h ) ) ok
r s  append  print	     \ =>	( a b c d e f g h ) ok
r            print	     \ =>	( a b c d e ) ok
r s  nconc   print	     \ =>	( a b c d e f g h ) ok
r            print	     \ =>	( a b c d e f g h ) ok
s            print	     \ =>	( f g h ) ok


'( ( a b ) c )  to  r
'( a b )  to  s

s  r  member  print			\ =>	nil ok
s  r  ' equal  member:test  print	\ =>	( ( a b ) c ) ok

s  r  reverse  ' equal member:test print  \ =>	( ( a b ) ) ok

r  print				\ =>    ( ( a b ) c ) ok
r  reverse  to  r
r  print				\ =>	( c ( a b ) ) ok


\ Demonstrate set operations

'( a b c d ) to r
'( c d e )   to s

r s  intersection	print		\ =>	( c d )
r s  union		print		\ =>	( a b c d e )
r s  set-difference	print		\ =>	( a b )
s r  subsetp		.		\ =>	0
quote b s  adjoin	print		\ =>	( b c d e )
quote c s  adjoin	print		\ =>	( c d e )
	 
cr .stat

