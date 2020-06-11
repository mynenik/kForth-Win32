\ stats.4th
\
\ Copyright (c) 1998 Krishna Myneni
\ Last Revised: 12-22-1998
\
\ Compute the mean and variance of a set of floating point numbers
\
\ Example:	1.3e 3.4e 2.1e 1.9e 4 stats
\
\ The words "mean", "variance", and "stats" expect on the stack
\ a series of floating point numbers followed by the integer count:
\
\	f1 f2 ... fn n --
\
\ This sequence is referred to as an "frc". The file
\ matrix.4th must be present.
\ 

include matrix

fvariable mu
fvariable sigma2

: mean ( frc -- fmu | compute mean )
	0e rot dup >r 
	0 do f+ loop 
	r> s>f f/ 
	fdup mu f! ;

: variance ( frc -- fsigma2 | compute variance )
	dup >r 
	frc_dup mean
	rot 0e rot 
	0 do >r >r fdup frot f- fdup f* r> r> f+ loop
	fswap fdrop 
	r> 1- s>f f/ 
	fdup sigma2 f! ;

: stats ( frc -- | compute and print the statistics )
	variance
	mu f@ cr 
	." Mean = " f. cr
	." Variance = " f. cr ;
	
	
