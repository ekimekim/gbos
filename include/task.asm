IF !DEF(_G_TASK)
_G_TASK EQU "true"


; --- Task struct ---
RSRESET
task_sp rw 1 ; stack pointer. When this is $00xx, the task slot is considered empty (valid stack can't be in $00 page, this is ROM)
task_rombank rb 1 ; loaded rom bank, or 0
task_rambank rb 1 ; loaded ram bank, or 0
task_waiter rw 1 ; address of waiter being waited on by task, or ffff.
                 ; Note that uniquely identifying waiter may rely on addr + current ram bank info,
                 ; either SRAM (top 3 bits = 101), or WRAM (top 3 bits = 110).

TASK_SIZE rb 0

; A task not currently running has the following on top of its stack:
; user stack, PC, junk(16bit), AF, BC, DE, HL, (top)
; Tasks should ensure the stack has enough room to write these 12 bytes at all times.

MAX_TASKS EQU 31

IF MAX_TASKS * TASK_SIZE >= 256
FAIL "Since CurrentTask is only 1 byte, TaskList must fit within 256 bytes"
ENDC

ENDC
