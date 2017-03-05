include "hram.asm"
include "task.asm"


SECTION "Task List", WRAM0

TaskList::
	ds MAX_TASKS * TASK_SIZE


SECTION "Task switching", ROM0


; Save task state from current cpu state and transitions into the (blank) core stack.
; Interrupts must be disabled.
; Expects the top of stack to look like: (top), Return address, PC of task, user stack
TaskSave::
	; We must be careful here not to lose register values before saving them
	; Our first step is to save HL so we can use it
	ld [Scratch], HL
	; Now it's safe to pop our return address and save it
	pop HL
	ld [Scratch+2], HL
	; Now we can restore HL and safely push everything to the user's stack
	ld HL, [Scratch]
	push AF
	push BC
	push DE
	push HL
	; Now we can save and switch stacks
	ld HL, SP
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
	; Restore original return address and return
	ld HL, [Scratch+2]
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
	; TODO set banks
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
