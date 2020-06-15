\ scr2txt.4th
\
\ Copyright (c) 1999 Krishna Myneni
\ 
\ Convert LMI screen file (block file) into a text file.
\
\ This software is provided under the GNU General Public
\   License.
\
include ans-words
include strings
include files

create ifname 80 allot
create ofname 80 allot

variable if_id
variable of_id

create lbuf 80 allot

: scr2txt ( -- )
	." Enter screen file name: "
	ifname 80 accept
	ifname swap R/O open-file
	if
	  cr ." Error opening input file." cr
	  drop exit
	then
	if_id !
	cr ." Enter text file name: "
	ofname 80 accept
	ofname swap R/W create-file
	if
	  cr ." Error opening output file." cr
	  drop
	  if_id @ close-file drop 
	  exit
	then
	of_id !
	
	begin
	  lbuf 64 if_id @ read-file
	  drop 0=
	  if
	    \ Reached end of input file

	    if_id @ close-file drop
	    of_id @ close-file drop
	    exit
	  then
	  lbuf 64 -trailing of_id @ write-line drop
	again ;

	  	


