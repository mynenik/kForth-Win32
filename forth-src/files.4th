\ files.4th (Win32 version)
\
\ This code provides kForth with most of the Forth-94 standard
\ File Access word set.
\
\ kForth provides the built-in low level file access words:
\
\   OPEN  LSEEK  CLOSE  READ  WRITE  FSYNC
\
\ The definitions below provide standard and non-standard Forth
\ file i/o words and constants.
\
\ Glossary:
\
\   CREATE-FILE  ( c-addr u fam -- fd ior )
\   OPEN-FILE    ( c-addr u fam -- fd ior )
\   CLOSE-FILE   ( fd -- ior )
\   READ-FILE    ( c-addr u1 fd -- u2 ior )
\   WRITE-FILE   ( c-addr u fd -- ior )
\   FILE-POSITION    ( fd -- ud ior )
\   REPOSITION-FILE  ( ud fd -- ior )
\   FILE-SIZE    ( fd -- ud ior )
\   FILE-EXISTS  ( ^filename -- flag )
\   READ-LINE    ( c-addr u1 fd -- u2 flag ior )
\   WRITE-LINE   ( c-addr u fd -- ior )
\
\ Copyright (c) 1999--2020 Krishna Myneni
\
\ This software is provided under the terms of the GNU General
\ Public License.
\
\ Requires:
\
\  strings.4th
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

\ CREATE-FILE  ( c-addr u fam -- fileid ior )
\ Create a file with the specified name.
: create-file
	>r strpck r> O_CREAT or open
	dup 0> invert ;

\ OPEN-FILE  ( c-addr u fam -- fileid ior )
\ Open the file with the specified name and access method.
: open-file
	>r strpck r> open
	dup 0> invert ;

\ CLOSE-FILE ( fileid -- ior )
\ Close the file identified by fileid.
: close-file  close ;

\ READ-FILE ( c-addr u1 fileid -- u2 ior )
\ Read u1 characters from specified file into buffer at c-addr.
: read-file  -rot read dup -1 = ;

\ WRITE-FILE ( c-addr u fileid -- ior )
\ Write u characters to file from buffer at c-addr.
: write-file  -rot write 0< ;

\ FILE-POSITION ( fileid -- ud ior )
\ Return the current file position, ud, for the specified file.
: file-position
	0 SEEK_CUR lseek dup -1 = >r s>d r> ;

\ REPOSITION-FILE ( ud fileid -- ior )
\ Change the current file position to ud for the specified file.
: reposition-file
	-rot drop SEEK_SET lseek 0< ;

\ FILE-SIZE ( fileid -- ud ior )
\ Return the size in pchars, ud, for the specified file.
: file-size
	dup >r r@ file-position drop 2>r
	0 SEEK_END lseek dup -1 = >r s>d r> 
	2r> r> reposition-file drop ;

\ FILE-EXISTS ( ^filename -- flag )
\ Return true if the named file in counted string exists.
\ Non-standard word.
: file-exists
	count R/O open-file
	if drop false else close-file drop true then ;	

\ READ-LINE ( c-addr u1 fileid -- u2 flag ior )
\ Read the next line from the file into memory at c-addr
: read-line
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

\ WRITE-LINE ( c-addr u fileid -- ior )
\ Write u characters from c-addr followed by a line terminator
: write-line
	dup >r write-file
	EOL_BUF 1 r> write-file
	or ;

