\  LZ77 Data Compression
\
\
\                                                  Wil Baden  1994-12-09
include strings
include files

\ =================================================================
\        General Utilities
\ =================================================================

    : CHARS ;  ( needed for kForth)

    \ : checked ABORT" File Access Error. " ;      ( ior -- )
    \ : Checked FILE-CHECK ;
    : Checked DROP ;

    CREATE Single-Char-I/O-Buffer    3 CHARS ALLOT

    : Read-Char                    ( file -- char )
        Single-Char-I/O-Buffer 1 ROT READ-FILE Checked IF
            Single-Char-I/O-Buffer C@
        ELSE
            -1
        THEN ;

    : Write-String   WRITE-FILE Checked ;

    : Closed CLOSE-FILE Checked ;

    : 'th   ( n "addr" -- addr+4n )
    	S" CELLS " EVALUATE
        BL WORD COUNT EVALUATE
        S" + " EVALUATE
        ; IMMEDIATE

    : BUFFER:   CREATE  ALLOT ;

\ =================================================================
\       Data
\ =================================================================

\      LZSS -- A Data Compression Program
\      1989-04-06 Standard C by Haruhiko Okumura
\      1994-12-09 Standard Forth by Wil Baden
\      2001-O9-15 Minor changes and reformatting by Wil Baden 

\      Use, distribute, and modify this program freely.  [Haruhiko Okumura]


\      [Comments by Haruhiko Okumura]

4096  CONSTANT    N     \  Size of Ring Buffer
18    CONSTANT    F     \  Upper Limit for match-length
2     CONSTANT    THRESHOLD  \  Encode string into position & length
                        \  when match-length is greater.
N     CONSTANT    NIL   \  Index for Binary Search Tree Root

VARIABLE    Textsize    \  Text Size Counter
VARIABLE    Codesize    \  Code Size Counter

\  These are set by Insert-Node procedure.

VARIABLE    Match-Position
VARIABLE    Match-Length

N  F 1-  +  2 +  BUFFER: Text-Buf   \  Ring buffer of size N, with extra
                            \  F-1 bytes to facilitate string comparison.

\  Left & Right Children and Parents -- Binary Search Trees

N 1+    CELLS BUFFER: LSon
N 257 + CELLS BUFFER: RSon
N 1+    CELLS BUFFER: DAD

\  Input & Output Files

VARIABLE In-File
VARIABLE Out-File

\  For i = 0 to N - 1, RSon[i] and LSon[i] will be the right and
\  left children of node i.  These nodes need not be initialized.
\  Also, DAD[i] is the parent of node i.  These are initialized to
\  NIL = N, which stands for "not used".
\  For i = 0 to 255, RSon[N + i + 1] is the root of the tree
\  for strings that begin with character i.  These are initialized
\  to NIL.  Note there are 256 trees.

      : N-MOD   4095 AND ;   \  Modulo N

\ =================================================================
\        Initialize trees
\ =================================================================

\  Initialize trees.

: Init-Tree                                \ ( -- )
      N 257 +  N 1+  DO  NIL  I 'th RSon !  LOOP
      N  0  DO  NIL  I 'th DAD !  LOOP
      0 Textsize !  0 Codesize ! ;

\ =================================================================
\        Insert-Node
\ =================================================================


\  Insert string of length F, Text-Buf[r..r+F-1], into one of the
\  trees of Text-Buf[r]'th tree and return the longest-match position
\  and length via the global variables Match-Position and
\  Match-Length.  If Match-Length = F, then remove the old node in
\  favor of the new one, because the old one will be deleted sooner.
\  Note r plays double role, as tree node and position in buffer.

: Insert-Node                              ( r -- )
      NIL over 'th LSon !    NIL over 'th RSon !    0 Match-Length !
      dup Text-Buf + C@  N +  1+                ( r p)
      1                                         ( r p cmp)
      BEGIN                                     ( r p cmp)
            0< NOT IF                           ( r p)
                  dup 'th RSon @ NIL = NOT IF
                        'th RSon @
                  ELSE
                        2dup 'th RSon !
                        SWAP 'th DAD !          ( )
                  EXIT THEN
            ELSE                                ( r p)
                  dup 'th LSon @ NIL = NOT IF
                        'th LSon @
                  ELSE
                        2dup 'th LSon !
                        SWAP 'th DAD !          ( )
                  EXIT THEN
            THEN                                ( r p)
            0 F dup 1 DO                        ( r p . .)
                  3 PICK I + Text-Buf + C@      ( r p . .  c)
                  3 PICK I + Text-Buf + C@ -    ( r p . . cmp)
                  ?dup IF  NIP NIP  I  LEAVE  THEN  ( r p . .)
            LOOP                                ( r p cmp i)
            dup Match-Length @ > IF
                  2 PICK Match-Position !
                  dup Match-Length !
                  F < NOT
            ELSE
                  DROP FALSE
            THEN                                ( r p cmp flag)
      UNTIL                                     ( r p cmp)
      DROP                                      ( r p)
      2dup 'th DAD @ SWAP 'th DAD !
      2dup 'th LSon @ SWAP 'th LSon !
      2dup 'th RSon @ SWAP 'th RSon !
      2dup 'th LSon @ 'th DAD !
      2dup 'th RSon @ 'th DAD !
      dup 'th DAD @ 'th RSon @ over = IF
            TUCK 'th DAD @ 'th RSon !
      ELSE
            TUCK 'th DAD @ 'th LSon !
      THEN                                      ( p)
      'th DAD NIL SWAP !    \  Remove p         ( )
      ;

\ =================================================================
\        Delete-Node
\ =================================================================

\  Delete node p from tree.

: Delete-Node                              ( p -- )
      dup 'th DAD @ NIL = IF  DROP  EXIT THEN   \  Not in tree.
      dup 'th RSon @ NIL = IF
            dup 'th LSon @
      ELSE
      dup 'th LSon @ NIL = IF
            dup 'th RSon @
      ELSE
            dup 'th LSon @                      ( p q)
            dup 'th RSon @ NIL = NOT IF
                  BEGIN
                        'th RSon @
                        dup 'th RSon @ NIL =
                  UNTIL
                  dup 'th LSon @ over 'th DAD @ 'th RSon !
                  dup 'th DAD @ over 'th LSon @ 'th DAD !
                  over 'th LSon @ over 'th LSon !
                  over 'th LSon @ 'th DAD over SWAP !
            THEN
            over 'th RSon @ over 'th RSon !
            over 'th RSon @ 'th DAD over SWAP !
      THEN THEN                                ( p q)
      over 'th DAD @ over 'th DAD !
      over dup 'th DAD @ 'th RSon @ = IF
            over 'th DAD @ 'th RSon !
      ELSE
            over 'th DAD @ 'th LSon !
      THEN                                      ( p)
      'th DAD NIL SWAP ! ;                      ( )

\ =================================================================
\        Statistics
\ =================================================================

: Statistics                              ( -- )
      ." In : "   Textsize ?   CR
      ." Out: "   Codesize ?   CR
      Textsize @ IF
            ." Saved: " Textsize @  Codesize @ -  100 Textsize @ */
                  2 .R ." %" CR
      THEN
      In-File @ Closed    Out-File @ Closed
      ;

\ =================================================================
\        Encode
\ =================================================================

      17 2 + BUFFER:  Code-Buf

      VARIABLE    Len
      VARIABLE    Last-Match-Length
      VARIABLE    Code-Buf-Ptr

      VARIABLE    Mask

: Encode                                  ( -- )
      Init-Tree    \  Initialize trees.

      \  Code-Buf[1..16] holds eight units of code, and Code-Buf[0]
      \  works as eight flags, "1" representing that the unit is an
      \  unencoded letter in 1 byte, "0" a position-and-length pair
      \  in 2 bytes.  Thus, eight units require at most 16 bytes
      \  of code.

      0 Code-Buf C!
      1 Mask C!   1 Code-Buf-Ptr !
      0  N F -                                  ( s r)

      \  Clear the buffer with a character that will appear often.
      Text-Buf  N F -  BL  FILL

      \  Read F bytes into the last F bytes of the buffer.
      dup Text-Buf + F In-File @ READ-FILE Checked   ( s r count)
      dup Len !  dup Textsize !
      0= IF  2DROP  EXIT THEN                   ( s r)

      \  Insert the F strings, each of which begins with one or more
      \  "space" characters.  Note the order in which these strings
      \  are inserted.  This way, degenerate trees will be less
      \  likely to occur.

      F  1+ 1 DO  dup I - Insert-Node  LOOP

      \  Finally, insert the whole string just read.  The global
      \  variables Match-Length and Match-Position are set.
      dup ( r) Insert-Node

      BEGIN                                     ( s r)
            \  Match-Length may be spuriously long at end of text.
            Match-Length @ Len @ > IF  Len @ Match-Length !  THEN

            Match-Length @ THRESHOLD > NOT IF
                  \  Not long enough match.  Send one byte.
                  1 Match-Length !
                  \  "send one byte" flag
                  Mask C@ Code-Buf C@ OR Code-Buf C!
                  \  Send uncoded.
                  dup Text-Buf + C@ Code-Buf-Ptr @ Code-Buf + C!
                  1 Code-Buf-Ptr +!
            ELSE
                  \  Send position and length pair.
                  \  Note Match-Length > THRESHOLD.
                  Match-Position @  Code-Buf-Ptr @ Code-Buf + C!
                  1 Code-Buf-Ptr +!
                  Match-Position @  8 RSHIFT  4 LSHIFT ( . . j)
                        Match-Length @  THRESHOLD -  1-  OR
                        Code-Buf-Ptr @  Code-Buf + C!  ( . .)
                  1 Code-Buf-Ptr +!
            THEN
            \  Shift mask left one bit. )        ( . .)
            Mask C@  2*  Mask C!  Mask C@ 0= IF
                  \  Send at most 8 units of code together.
                  Code-Buf  Code-Buf-Ptr @    ( . . a k)
                        Out-File @ Write-String ( . .)
                  Code-Buf-Ptr @  Codesize  +!
                  0 Code-Buf C!    1 Code-Buf-Ptr !    1 Mask C!
            THEN                                ( s r)
            Match-Length @ Last-Match-Length !
            Last-Match-Length @ dup 0 DO        ( s r n)
                  In-File @ Read-Char           ( s r n c)
                  dup 0< IF  2DROP I LEAVE  THEN
                  \  Delete old strings and read new bytes.
                  3 PICK ( s) Delete-Node
                  dup 4 PICK ( c s) Text-Buf + C!
                  \  If the position is near end of buffer, extend
                  \  the buffer to make string comparison easier.
                  3 PICK ( s) F 1- < IF         ( s r n c)
                        dup 4 PICK ( c s) N + Text-Buf + C!
                  THEN
                  DROP                          ( s r n)
                  \  Since this is a ring buffer, increment the
                  \  position modulo N.
                  >R >R                         ( s)
                        1+  N-MOD
                  R>                            ( s r)
                        1+  N-MOD
                  R>                            ( s r n)
                  \  Register the string in Text-Buf[r..r+F-1].
                  over Insert-Node
            LOOP                                ( s r i)
            dup Textsize +!

            \  After the end of text, no need to read, but
            \  buffer might not be empty.
            Last-Match-Length @ SWAP ( s r l i) ?DO  ( s r)
                  over Delete-Node
                  >R  ( s) 1+  N-MOD  R>
                  ( r) 1+  N-MOD
                  -1 Len +!  Len @ IF
                        dup Insert-Node
                  THEN
            LOOP

            Len @ 0> NOT
      UNTIL  2DROP                              ( )

      \  Send remaining code.
      Code-Buf-Ptr @ 1 > IF
            Code-Buf  Code-Buf-Ptr @  Out-File @ Write-String
            Code-Buf-Ptr @ Codesize +!
      THEN

      Statistics ;

\ =================================================================
\        Decode
\ =================================================================

\  Just the reverse of Encode.

: Decode                                  ( -- )
      \  [Warning: Does not close In-File or Out-File.]
      Text-Buf  N F -  BL FILL
      0  N F -                                  ( flags r)
      BEGIN
            >R                                  ( flags)
                  1 RSHIFT dup 256 AND 0= IF DROP     ( )
                        In-File @ Read-Char       ( c)
                        dup 0< IF  R> 2DROP  EXIT THEN
                        [ HEX ] 0FF00 [ DECIMAL ] OR ( flags)
                        \  Uses higher byte to count eight.
                  THEN
            R>                                  ( flags r)
            over 1 AND IF
                  In-File @ Read-Char           ( . r c)
                  dup 0< IF  DROP 2DROP  EXIT THEN
                  over Text-Buf + C!            ( . r)
                  dup Text-Buf + 1 Out-File @ Write-String
                  1+  N-MOD
            ELSE
                  In-File @ Read-Char           ( . r i)
                  dup 0< IF  DROP 2DROP  EXIT THEN
                  In-File @ Read-Char           ( . . i j)
                  dup 0< IF  2DROP 2DROP  EXIT THEN
                  dup >R  4 RSHIFT  8 LSHIFT OR  R>
                  15 AND  THRESHOLD +  1+
                  0 ?DO                                  ( . r i)
                        dup I +  N-MOD  Text-Buf +       ( . r i addr)
                        dup 1 Out-File @ Write-String
                        C@  2 PICK ( c r) Text-Buf + C!  ( . r i)
                        >R  ( r) 1+  N-MOD  R>
                  LOOP                          ( . r i)
                  DROP                          ( flags r)
            THEN
      AGAIN ;

\  End of LZ77
