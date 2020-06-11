\ ftest.4th
\
\ Test i/o from files
\
\ Requires the following 4th files:
\
\	strings.4th
\	files.4th (linux) or filesw.4th (for windows)
\
variable f1
create line_buf 256 allot

: ftest1 ( -- | write and read ten numbers to/from the file ftest1.dat )

	\ create file and write to it
	
	cr ." Writing to file ftest1.dat ..."
	" ftest1.dat" count R/W create-file
	if 
	  ." Error creating file" cr drop exit
	then
	f1 !
	10 0 do 
	  i s>string 
	  count f1 @ write-line
	  drop
	loop
	f1 @ close-file
	drop
	." Done."

	\ now re-open the file and read from it
	
	cr ." Now reading from file ftest1.dat ..."
	cr
	" ftest1.dat" count R/O open-file
	if
	  ." Error opening file" cr drop exit
	then
	f1 !
	begin
	  line_buf 256 f1 @ read-line
	  drop
	  if
	    line_buf swap strpck string>s
	    . cr
	  else
	    drop 
	    f1 @ close-file drop 
	    ." Done." cr exit
	  then
	again ;

