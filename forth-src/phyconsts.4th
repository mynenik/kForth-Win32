\ phyconsts.4th
\
\ Handy definitions for my Forth desktop environment
\
\ Requires:
\   ans-words.4th
\
\ Revisions:
\   2020-10-06  km  updated for 2019 redefinition of S.I. base units 

[undefined]  PI [IF] -1e facos fconstant  pi [THEN]
[undefined] 2PI [IF] pi 2e f*  fconstant  2pi [THEN]

\ Physical Constants

    9192631770e  fconstant  dnu_Cs \ hyperfine interval in Cs133 in s^-2 (exact)
     299792458e  fconstant  c	  \ speed of light in m/s  (exact)
 6.62607015e-34  fconstant  h     \ Planck's constant in J*s (exact)
h 2pi f/         fconstant  hbar  \ 
1.602176634e-19  fconstant  e     \ elementary charge in C  (exact)
1.380649e-23     fconstant  kB    \ Boltzmann's constant in J/K (exact)
6.02214076e23    fconstant  N_A   \ Avogadro constant mol^-1  (exact)

\ Measured Constants
9.10938188e-31   fconstant  m_e   \ electron mass in kg
1.67262158e-27   fconstant  m_p   \ proton mass in kg
8.854187817e-12  fconstant  eps0  \ electric constant in F/m

\ Derived Constants
137.035999139e   fconstant  alpha^-1  \ inverse fine structure constant

\ Unit Conversions
e                fconstant  J/eV     \ electron volts -> Joules
1.66053873e-27   fconstant  kg/amu   \ atomic mass unit -> kilograms
219474.6314e     fconstant  cm^-1/Eh \ Hartree to wavenumber conversion
0.5291772083e    fconstant  A/a0     \ Bohr radii to Angstroms conversion

0 [IF]
.( Defined FCONSTANTs [physical constants in MKS units]: ) CR CR
.(        pi ) CR
.(       2pi ) CR
.(         c     speed of light [exact]) CR
.(         h     Planck's constant [exact]) CR
.(      hbar ) CR
.(         e     elementary charge [exact]) CR
.(        kB     Boltzmann's constant [exact]) CR
.(       N_A     Avogadro constant [exact]) CR
.(       m_e     electron mass ) CR
.(       m_p     proton mass ) CR
.(      eps0     permitivitty of free space ) CR
.(  alpha^-1     inverse fine structure constant ) CR
CR
.( Conversions between units: ) CR CR
.(      J/eV     eV -> J ) CR
.(    kg/amu     amu -> kg ) CR
.(  cm^-1/Eh     Hartree -> wavenumber ) CR
.(      A/a0     Bohr radius -> Angstroms ) CR
CR CR
[THEN]

