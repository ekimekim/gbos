include "hram.asm"
include "task.asm"
include "macros.asm"
include "longcalc.asm"


SECTION "Task List", WRAM0

TaskList::
	ds MAX_TASKS * TASK_SIZE


SECTION "Task switching", ROM0


; Save task state from current cpu state and transitions into the (blank) core stack.
; Expects the top of stack to look like: (top), Return address, PC of task, user stack
TaskSave::
	; We must be careful here not to lose register values before saving them
	push AF
	push BC
	push DE
	push HL
	; Before leaving this stack, we need to pull out the return address,
	; which is now 8 bytes into the stack
	ld HL, SP+8
	ld D, H
	ld E, L ; DE = return address
	; Now we can save SP and switch stacks
	ld HL, SP+0
	ld B, H
	ld C, L ; BC = SP
	LongAdd 0,[CurrentTask], ((TaskList+task_sp) >> 8),((TaskList+task_sp) & $ff), H,L ; HL = TaskList + CurrentTask + task_sp = &(TaskList[CurrentTask].task_sp)
	; Save SP to task struct
	ld [HL], B
	inc HL
	ld [HL], C
	; Load core stack
	ld HL, CoreStackBase
	ld SP, HL
	; Return to saved address
	ld H, D
	ld L, E ; HL = return address
	jp [HL]


; Load task state and return into the task.
; Does not return to called function - in fact, it ignores the current stack completely.
; Takes task ID to load in A.
TaskLoad::
	ld [CurrentTask], A
	; HL = TaskList + A + task_sp = &(TaskList[A].task_sp)
	add (TaskList+task_sp) & $ff
	ld L, A
	ld A, 0
	adc (TaskList+task_sp) >> 8
	ld H, A
	; BC = [HL] = stored stack pointer
	ld B, [HL]
	inc HL
	ld C, [HL]
	; Set ROM and RAM banks, if any
	RepointStruct HL, task_sp+1, task_rombank
	ld A, 0
	add [HL]
	jr z, .noROM
	SetROMBank
	ld A, 0
.noROM
	RepointStruct HL, task_rombank, task_rambank
	add [HL]
	jr z, .noRAM
	SetRAMBank
.noRAM
	; set stack pointer
	ld H, B
	ld L, C
	ld SP, HL
	; restore regs
	pop HL
	pop DE
	pop BC
	pop AF
	; at this point, the top of the user's stack should be the PC to return to
	ret
