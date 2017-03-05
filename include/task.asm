
; --- Task struct ---
RSRESET
task_sp rw 1 ; stack pointer
task_rombank rb ; loaded rom bank, or 0
task_rambank rb ; loaded ram bank, or 0

TASK_SIZE rb 0

; A task not currently running has the following on top of its stack:
; user stack, PC, AF, BC, DE, HL, (top)
; Tasks should ensure the stack has enough room to write these 10 bytes at all times.

MAX_TASKS EQU 32

IF MAX_TASKS * TASK_SIZE >= 256
FAIL "Since CurrentTask is only 1 byte, TaskList must fit within 256 bytes"
ENDC
