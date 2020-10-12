\ matfiles.4th
\
\ Write and read matrices to/from files
\
\ Copyright (c) 1999--2001 Krishna Myneni
\ Provided under the terms of the GNU General Public License
\
\ Required source files:
\
\	matrix.4th
\	strings.4th
\	files.4th
\
\ Revisions:
\
\	3-26-1999 created  KM
\	5-7-1999  added write_fmat_ascii_file  KM
\	5-11-2000 added read_mat_file, write_fmat_file, read_fmat_file  KM
\	10-02-2001 added read_fmat_ascii_file  KM

variable matfile_fd

: write_mat_file ( a ^name -- | write a binary integer matrix file )
  \ a is the address of the matrix buffer
  \ ^name is a counted string containing the filename,
  count W/O create-file 
  if 
    2drop
    cr ." Error opening file." cr  
    exit 
  then
  matfile_fd !
  dup mat_size@ * cells 8 + 
  matfile_fd @ write-file
  cr . ." bytes written to file." cr
  matfile_fd @ close-file drop ;


: read_mat_file ( a ^name -- | read a binary integer matrix file )
  \ a is the address of the matrix buffer (ensure that you allocated
  \   enough space to hold the matrix being read from the file).
  \ ^name is a counted string containing the filename.
  count R/O open-file
  if
    2drop
    cr ." Error opening file." cr
    exit
  then
  matfile_fd !
  dup 2 cells matfile_fd @ read-file	\ read the matrix size
  if
    2drop
    cr ." Error reading matrix size." cr
  else
    drop
    dup mat_size@ * cells >r 8 + r>
    matfile_fd @ read-file		\ read the matrix body
    if
      cr ." Error reading matrix data." cr
    then
    8 + . ." bytes read from file." cr
  then
  matfile_fd @ close-file drop ;


: write_fmat_file ( a ^name -- | write a binary floating point  matrix file )
  \ a is the address of the matrix buffer
  \ ^name is a counted string containing the filename,
  count W/O create-file 
  if 
    2drop
    cr ." Error opening file." cr  
    exit 
  then
  matfile_fd !
  dup mat_size@ * dfloats 8 + 
  matfile_fd @ write-file
  cr . ." bytes written to file." cr
  matfile_fd @ close-file drop ;
 

: read_fmat_file ( a ^name -- | read a binary floating point matrix file )
  \ a is the address of the matrix buffer (ensure that you allocated
  \   enough space to hold the matrix being read from the file).
  \ ^name is a counted string containing the filename.
  count R/O open-file
  if
    2drop
    cr ." Error opening file." cr
    exit
  then
  matfile_fd !
  dup 2 cells matfile_fd @ read-file	\ read the matrix size
  if
    2drop
    cr ." Error reading matrix size." cr
  else
    drop
    dup mat_size@ * dfloats >r 8 + r>
    matfile_fd @ read-file		\ read the matrix body
    if
      cr ." Error reading matrix data." cr
    then
    8 + . ." bytes read from file." cr
  then
  matfile_fd @ close-file drop ;

create ascii_buf 256 allot
variable matptr
variable matrcntr

: read_fmat_ascii_file ( a ^name -- | read an ascii floating pt matrix file)
	swap matptr !
	count R/O open-file
	if 2drop cr ." Error opening file." cr exit then
	matfile_fd !
	0 matrcntr !
	begin
	  ascii_buf 256 matfile_fd @ read-line
	  0= if 
	    drop ascii_buf swap -trailing parse_args
	    dup 0> if 1 matrcntr +! matrcntr @ 
	      \ dup . over . cr 
	      matptr a@ frow! -1 then
	  else
	    2drop 0
	  then
	  0= matrcntr @ matptr a@ mat_size@ drop = or 
	until
	matfile_fd @ close-file drop
	matrcntr @ . ." rows read from file." cr ;


: write_mat_ascii_file ( a ^name -- | write an ascii integer matrix file )
  count W/O create-file 
  if 
    2drop
    cr ." Error opening file." cr  
    exit 
  then
  matfile_fd !
  dup mat_size@ swap
  0 do
    "  "
    over 0 do
      j 1+ i 1+ 4 pick mat@
      swap count rot s>string count strcat
      "   " count strcat strpck
    loop
    count matfile_fd @ write-line drop
  loop
  2drop 
  matfile_fd @ close-file drop ;



: write_fmat_ascii_file ( a ^name -- | write floating pt matrix file )
	count W/O create-file
	if
	  2drop
	  cr ." Error opening file." cr
	  exit
	then
	matfile_fd !
	dup mat_size@ swap
	0 do
	  "  "
	  over 0 do
	    j 1+ i 1+ 4 pick fmat@ 6 f>string
	    >r count r> count strcat
	    "   " count strcat strpck
	  loop
	  count matfile_fd @ write-line drop
	loop
	2drop
	matfile_fd @ close-file drop ;
       



