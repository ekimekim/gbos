RSSET $ff80

; Scratch space that OS functions can use during critical operations.
; Expect it to be clobbered by any other function.
; Use only with interrupts disabled as interrupts may clobber it.
Scratch rb 8 

; Currently running (or most recent) task ID. A task ID is an offset into the tasks array.
CurrentTask rb 1
