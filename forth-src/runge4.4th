\ runge4.4th    Runge-Kutta ODE Solver for systems of ODEs
\
\ Forth Scientific Library Algorithm #29
\   Adapted for integrated fp/data stack Forths (km 2003-03-18)
\
\ )runge_kutta4_init ( 'dsdt n -- )
\               Initialize to use function dsdt() for n equations,
\               its stack diagram is:
\                      dsdt() ( ft 'u 'dudt -- ) 
\               (the values in the array dudt get changed)
\
\ runge_kutta4_integrate() ( t dt 'u steps -- t' )
\               Integrate the equations STEPS time steps of size DT,
\               starting at time T and ending at time T'.  U is the
\               initial condition on input and the new state of the 
\               system on output.

\ runge_kutta4_done  ( -- )
\               Release previously allocated space.

\ )rk4qc_init ( maxstep eps 'dsdt n 's -- )
\               Initialize to use function dsdt() for n equations.
\               The initial function values are in s{. The output is also
\		in s{. The result is computed with a 5th-order Runge-Kutta
\ 		routine with adaptive step size control. The step size 
\		controller tries to keep the fractional error of any s{ 
\		component below eps. The maximum step size is limited to 
\		maxstep .
\
\ rk4qc_done  ( -- )
\               Release previously allocated space.
\
\ rk4qc_step ( step t -- step' t' flag )
\		Do one Runge-Kutta step, using adaptive step size control.
\		The flag is FALSE if the routine succeeds, else the step size
\		has become too small. The current step size and time are on 
\		the stack and will be updated by the routine.

\ This is an ANS Forth program requiring:
\      1. The Floating-Point word set
\      2. Uses words 'Private:', 'Public:' and 'Reset_Search_Order'
\         to control visibility of internal code
\      3. The word 'v:' to define function vectors and the
\         immediate 'defines' to set them.
\      4. The immediate words 'use(' and '&' to get function addresses
\      5. The words 'DARRAY' and '&!' to alias arrays.
\      6. Uses '}malloc' and '}free' to allocate and release memory
\         for dynamic arrays ( 'DARRAY' ).
\      7. The compilation of the test code is controlled by the VALUE
\         TEST-CODE? and the conditional compilation words in the
\          Programming-Tools wordset.
\  N/A 8. To run the code the fp stack needs to be at least 5 deep.
\	  To run all examples you need 7 positions on the fp stack.
\
\     (c) Copyright 1994  Everett F. Carter.     Permission is granted
\     by the author to use this software for any application provided
\     this copyright notice is preserved.

\ (The adaptive code was contributed by Marcel Hendrix)
\ (The integrated fp/data stack modifications are by Krishna Myneni, 2003-3-18)
\
\ kForth requires:
\
\	ans-words.4th
\	fsl-util.4th
\	dynmem.4th

CR .( RUNGE4            V1.2          15 November 1994   EFC )



Private:

v: dsdt()                     \ pointer to user function t, u, dudt

FLOAT DARRAY dum{             \ scratch space
FLOAT DARRAY dut{
FLOAT DARRAY ut{
FLOAT DARRAY dudt{

FVARIABLE h

FLOAT DARRAY u{               \ pointer to user array

0 VALUE dim


Public:


: )runge_kutta4_init ( &dsdt n -- )
     TO dim
     defines dsdt()


     & dum{ dim }malloc
     malloc-fail? ABORT" runge_init failure (1) "

     & dut{ dim }malloc
     malloc-fail? ABORT" runge_init failure (2) "

     & ut{ dim }malloc
     malloc-fail? ABORT" runge_init failure (3) "

     & dudt{ dim }malloc
     malloc-fail? ABORT" runge_init failure (4) "

;

: runge_kutta4_done ( -- )

     & dum{ }free
     & dut{ }free
     & ut{ }free
     & dudt{ }free
;

Private:


: runge4_step ( t -- t' )

     FDUP u{ dudt{ dsdt()

     h F@ F2/
     dim 0 DO
             dudt{ I } F@ FOVER F* u{ I } F@ F+
             ut{ I } F!
            LOOP

     FOVER F+ ut{ dut{ dsdt()

     h F@ F2/
     dim 0 DO
             dut{ I } F@ FOVER F* u{ I } F@ F+
             ut{ I } F!
            LOOP

     FOVER F+ ut{ dum{ dsdt()

     h F@
     dim 0 DO
             dum{ I } F@ FOVER F* u{ I } F@ F+
             ut{ I } F!

             dum{ I } DUP F@ dut{ I } F@ F+ ROT F!             

           LOOP

     F+           \ tos is now t+dt

     FDUP ut{ dut{ dsdt()

     h F@ 6.0E0 F/
     dim 0 DO
              dudt{ I } F@ dut{ I } F@ F+
              dum{ I } F@ F2* F+
              FOVER F*
              u{ I } DUP >R F@ F+ R> F!
           LOOP

     FDROP
          
;

Public:

: runge_kutta4_integrate() ( t dt &u steps -- t')

     SWAP & u{ &!
     >R h F! R>

     0 ?DO runge4_step LOOP

;



Private:
	 1E-30 	   FCONSTANT tiny
	-0.20E0    FCONSTANT pgrow
	-0.25E0    FCONSTANT pshrink
	1e 15E0 F/ FCONSTANT fcor
	  0.9E0    FCONSTANT safety

4E0 safety F/  
1E0 pgrow  F/ F**  FCONSTANT errcon

FVARIABLE eps
FVARIABLE step
FVARIABLE tstart
FVARIABLE maxstep

FLOAT DARRAY uorig{
FLOAT DARRAY u1{
FLOAT DARRAY u2{
FLOAT DARRAY uscal{


\ Find reasonable scaling values to decide when to shrink step size.
: scale'm ( -- )
	tstart F@ uorig{ uscal{ dsdt()	
	dim 0 ?DO uscal{ I } DUP F@ step F@ F* FABS
		  uorig{ I }     F@ FABS F+ tiny F+
		  ROT F!		 
	    LOOP ;

\ With a trick the result of a step can be made accurate to 5th order.
: 4th->5th ( -- )
	dim 0 DO 		\ get 5th order truncation error
		 uorig{ I } DUP F@  FDUP  
	         u1{ I }    F@ F-  fcor F* 
		 F+  ROT F! 
	    LOOP ;

\ Test if the step size needs shrinking
: shrink? ( -- diff bool )
	0.0E0 ( errmax )
	dim 0 DO  
		uorig{ I } F@  u1{ I } F@  F-  
		uscal{ I } F@  F/  FABS FMAX  
	    LOOP  
	eps F@ F/  FDUP 1e F> ;

Public:

\ Initialize to use function dsdt() for n equations. The initial function 
\ values are in s{. The output is also in s{. The result is computed with a 
\ 5th-order Runge-Kutta routine with adaptive step size control. The step size 
\ controller tries to keep the fractional error of any s{ component below eps.
\ The maximum step size is limited to maxstep .
: )rk4qc_init	   ( maxstep eps 'dsdt n 'u -- )
	& uorig{ &! 
	)runge_kutta4_init
	& u1{    dim }malloc malloc-fail? ABORT" )rk4qc_init :: malloc (1)" 
	& u2{    dim }malloc malloc-fail? ABORT" )rk4qc_init :: malloc (2)" 
	& uscal{ dim }malloc malloc-fail? ABORT" )rk4qc_init :: malloc (3)" 
	eps F! maxstep F! ;

\ Release previously allocated space.
: rk4qc_done  ( -- )
	runge_kutta4_done
	& u1{    }free 
	& u2{    }free 
	& uscal{ }free ;
\ Do one Runge-Kutta step, using adaptive step size control. The flag is 
\ FALSE if the routine succeeds, else the step size has become too small. 
\ The current step size and time are on the stack and will
\ be updated by the routine.

: rk4qc_step ( step t -- step' t' flag )
	tstart F!  step F!  scale'm
	uorig{ u1{ dim }fcopy	\ we need a fresh start after a shrink
	uorig{ u2{ dim }fcopy
   BEGIN	
	tstart F@ step F@ F2/ uorig{ 2 runge_kutta4_integrate() FDROP
	tstart F@ step F@ u1{    1     runge_kutta4_integrate() (  -- t' )
	FDUP tstart F@ 0.0E0 F~ IF 0.0E0 FSWAP FALSE EXIT THEN
	shrink?			\ maximum difference between these two tries
   WHILE			\ too large, shrink step size
	FLN pshrink F* FEXP step F@ F* safety F* step F!  FDROP
	u2{ uorig{ dim }fcopy	\ a fresh start after a shrink...
	u2{ u1{    dim }fcopy

  REPEAT			\ ok, grow step size for next time
	FDUP errcon F< IF  FDROP step F@ 4e F* 
		     ELSE  FLN pgrow F* FEXP step F@ F* safety F*
		     THEN 
	maxstep F@ FMIN		\ but don't grow excessively!
	FSWAP TRUE 4th->5th ;



Reset_Search_Order

