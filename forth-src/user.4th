\ user.4th
\
\ Determine user name on a Windows system.
\
\ Copyright (c) 2020 Krishna Myneni,
\
\ Requires:
\   ans-words.4th
\   strings.4th
\   files.4th
\   utils.4th
\
\ Revisions:

create username 64 allot		\ counted string

: get-username  ( -- a u )
    s" cmd.exe /c whoami > username" shell drop
    s" username" R/O open-file
    IF
      \ Unable to open the file, set username to NULL string
      drop 0 username !
      s" "
    ELSE
      dup username 1+ 63 rot read-line drop
      IF username c! ELSE drop 0 username ! THEN
      close-file drop
      username count dup IF
        s" \" search IF 1 /string THEN
      THEN
    THEN ;

