\ shellcmds.4th
\ 
\ Useful shell commands and other utilties made available from the
\ Forth environment
\
\  K. Myneni
\
\ Requires:
\   ans-words.4th
\   strings.4th
\   files.4th
\   utils.4th
\   macro.4th
\   hmac-md5.4th
\

: append-args ( a u "arglist" -- a2 u2 )
    10 word count strcat ;

: ls      S" cmd.exe /c dir "   append-args strpck system drop ;
: cd      10 word chdir drop ;
: rename  S" cmd.exe /c rename " append-args strpck system drop ;
: mv      S" cmd.exe /c move "   append-args strpck system drop ;
: mkdir   S" cmd.exe /c mkdir "  append-args strpck system drop ;
: rmdir   S" cmd.exe /c rmdir "  append-args strpck system drop ; 
: pwd     C" cmd.exe /c cd" system drop ;

.( Defined system commands: )
.(   ls  cd  rename  mv  mkdir  rmdir  pwd  md5file ) cr cr

