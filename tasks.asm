include "hram.asm"
include "task.asm"
include "macros.asm"
include "longcalc.asm"


SECTION "Task List", WRAM0

TaskList::
	ds MAX_TASKS * TASK_SIZE


SECTION "Task management", ROM0


; Create a new task with entry point in DE, and initial stack pointer in HL.
; For now, you must also provide the task id in B. This will be auto-allocated later.
TaskNew::
	; prepare the initial stack, which can be mostly garbage.
	dec HL
	ld [HL], D
	dec HL
	ld [HL], E ; push DE to stack at HL - this becomes the initial PC
	LongSub H,L, 0,10, D,E ; push 10 bytes of garbage to the stack and save in DE - this becomes junk + initial regs
	; fill in the task struct
	LongAdd 0,B, ((TaskList+task_sp) >> 8),((TaskList+task_sp) & $ff), H,L ; HL = TaskList + B + task_sp = &(TaskList[B].task_sp)
	ld [HL], D
	inc HL
	ld [HL], E ; [HL] = DE, this sets the initial stack pointer
	RepointStruct HL, task_sp+1, task_rombank
	ld [HL], 0
	RepointStruct HL, task_rombank, task_rambank
	ld [HL], 0
	call SchedAddTask ; schedule new task to run
	ret


; Save task state from current cpu state and transitions into the (blank) core stack.
; Expects the top of stack to look like: (top), Return address, PC of task, user stack
; (it is done this way so that 'call TaskSave' will save your caller and return to you,
; suitable for interrupt handlers, etc)
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
	ld HL, CoreStack
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
	LongAddToA ((TaskList+task_sp) >> 8),((TaskList+task_sp) & $ff), H,L ; HL = TaskList + A + task_sp = &(TaskList[A].task_sp)
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
	; the SaveTask process leaves some junk on the stack, skip it
	add SP, 2
	; at this point, the top of the user's stack should be the PC to return to
	ret


; Voluntarily give up task execution. Allows other tasks to run and returns some time later.
; Does not clobber any registers.
T_TaskYield::
	call TaskSave ; switch onto core stack
	; TODO scheduling stuff?
	jp SchedLoadNext
