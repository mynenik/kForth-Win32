\ files.4th (Win32 version)
\
\ This code provides kForth with a subset of the optional 
\ file access word set, following the guidelines of the ANS 
\ specifications.
\
\ Copyright (c) 1999--2020 Krishna Myneni
\ Creative Consulting for Research and Education
\
\ This software is provided under the terms of the GNU General
\ Public License.
\
base @
hex
0 constant R/O
1 constant W/O
2 constant R/W
A constant EOL
100 constant O_CREAT
400 constant O_EXCL
200 constant O_TRUNC
  8 constant O_APPEND
0 constant SEEK_SET
1 constant SEEK_CUR
2 constant SEEK_END
base !
create EOL_BUF 4 allot
EOL EOL_BUF c!
0 EOL_BUF 1+ c!

variable read_count

: create-file ( c-addr count fam -- fileid ior )
	>r strpck r> O_CREAT or open
	dup 0> invert ;

: open-file ( c-addr count fam -- fileid ior )
	>r strpck r> open
	dup 0> invert ;

: close-file ( fileid -- ior )
	close ;

: read-file ( c-addr u1 fileid -- u2 ior )
	-rot read dup -1 = ;
 	 
: write-file ( c-addr u fileid -- ior )
	-rot write 0< ;

: file-position ( fileid -- ud ior )
	0 SEEK_CUR lseek dup -1 = >r s>d r> ;

: reposition-file ( ud fileid -- ior )
	-rot drop SEEK_SET lseek 0< ;

: file-size ( fileid -- ud ior )
	dup >r r@ file-position drop 2>r
	0 SEEK_END lseek dup -1 = >r s>d r> 
	2r> r> reposition-file drop ;

: file-exists ( ^filename  -- flag | return true if file exists )
	count R/O open-file
	if drop false else close-file drop true then ;	

: read-line ( c-addr u1 fileid -- u2 flag ior )
	-rot 0 read_count !
	0 ?do
	  2dup 1 read
         dup 0< IF  >r 2drop read_count @ false r> unloop exit THEN
          0= IF    \ reached EOF
            read_count @ 0= IF 2drop 0 false 0 unloop exit
                            ELSE leave THEN
          THEN
          dup c@ EOL = IF 2drop read_count @ true 0 unloop exit THEN
          1+
          1 read_count +!
	loop
	2drop read_count @ true 0 ;

: write-line ( c-addr u fileid -- ior )
	dup >r write-file
	EOL_BUF 1 r> write-file
	or ;

