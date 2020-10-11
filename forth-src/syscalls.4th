\ syscalls.4th
\

BASE @

Module: syscalls
Begin-Module

Public:

HEX

\ Memory Allocation Type Constants

  1000   constant  MEM_COMMIT
  2000   constant  MEM_RESERVE
 80000   constant  MEM_RESET
1000000  constant  MEM_RESET_UNDO
  100000 constant  MEM_TOP_DOWN
  200000 constant  MEM_WRITE_WATCH
  400000 constant  MEM_PHYSICAL
20000000 constant  MEM_LARGE_PAGES


\ Memory Protection Constants

 1  constant  PAGE_NOACCESS
 2  constant  PAGE_READONLY
 4  constant  PAGE_READWRITE
 8  constant  PAGE_WRITECOPY
10  constant  PAGE_EXECUTE
20  constant  PAGE_EXECUTE_READ
40  constant  PAGE_EXECUTE_READWRITE
80  constant  PAGE_EXECUTE_WRITECOPY

\ Modifiers for Protection Constants
100 constant  PAGE_GUARD
200 constant  PAGE_NOCACHE
400 constant  PAGE_WRITECOMBINE

End-Module

BASE !


