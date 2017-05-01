
; --- Task struct ---
RSRESET
task_sp rw 1 ; stack pointer
task_rombank rb 1 ; loaded rom bank, or 0
task_rambank rb 1 ; loaded ram bank, or 0

TASK_SIZE rb 0

; A task not currently running has the following on top of its stack:
; user stack, PC, junk(16bit), AF, BC, DE, HL, (top)
; Tasks should ensure the stack has enough room to write these 12 bytes at all times.

MAX_TASKS EQU 31

IF MAX_TASKS * TASK_SIZE >= 256
FAIL "Since CurrentTask is only 1 byte, TaskList must fit within 256 bytes"
ENDC


; Start a new task of id \1 with stack \2 and entry point \3. Clobbers all. Must all be immediates.
TaskNewHelper: MACRO
	ld B, \1
	ld D, (\3) >> 8
	ld E, (\3) & $ff
	ld H, (\2) >> 8
	ld L, (\2) & $ff
	call TaskNew
	ENDM
