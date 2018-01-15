include "hram.asm"
include "task.asm"
include "macros.asm"
include "longcalc.asm"
include "constants.asm"


SECTION "Task List", WRAM0

TaskList::
	ds MAX_TASKS * TASK_SIZE


SECTION "Task management", ROM0


; Initialize task management structures
TaskInit::
	; Setting task_sp to $0000 marks it as unoccupied
	xor A
	ld B, MAX_TASKS
	ld HL, TaskList + task_sp
	jr .start
.loop
	LongAddConst HL, TASK_SIZE + (-2) ; TASK_SIZE - 2 is a syntax error for some reason
.start
	ld [HL+], A
	ld [HL+], A
	dec B
	jr nz, .loop
	ret


; Find the next free task id and return it in B, or 255 if none are free.
; Clobbers A, HL.
TaskFindNextFree:
	ld HL, TaskList + task_sp
	ld B, MAX_TASKS - 1
	jr .start
.loop
	dec B
	; if B underflowed, we checked all MAX_TASKS without breaking
	; and should return B = 255, which it is because it just underflowed
	ret c
	LongAddConst HL, TASK_SIZE + (-1) ; TASK_SIZE - n is a syntax error, assembler bug
.start
	ld A, [HL+]
	or [HL] ; set z only if both A and [HL] are 0
	jr nz, .loop
	; If we got here, HL = TaskList + first free task id + task_sp + 1
	; so we want to find HL - (TaskList + task_sp + 1).
	; Since we know the final result is < 256, we only need to do the lower half
	; of the subtraction. We don't care about the carry.
	ld A, L
	sub (TaskList + task_sp + 1) & $ff
	ld B, A
	ret


; Create a new task with entry point in DE, initial stack pointer in HL and inital ROM bank in C.
; Returns the new task id in B, or 255 if no task could be allocated.
TaskNewWithStack::
	; Pick a task id
	push HL
	call TaskFindNextFree
	pop HL
	ld A, B
	cp $ff
	ret z ; if B == 255, exit early with failure
	; fall through to TaskNewWithID
; Create a new task with entry point in DE, initial stack pointer in HL,
; initial ROM bank in C and new task id in B.
TaskNewWithID:
	; prepare the initial stack, which can be mostly garbage.
	dec HL
	ld A, D
	ld [HL-], A
	ld [HL], E ; push DE to stack at HL - this becomes the initial PC
	LongSub HL, 10, DE ; push 10 bytes of garbage to the stack and save in DE - this becomes junk + initial regs

	; fill in the task struct
	ld A, B
	LongAddToA TaskList+task_sp, HL ; HL = TaskList + B + task_sp = &(TaskList[B].task_sp)
	ld A, D
	ld [HL+], A
	ld A, E
	ld [HL+], A ; [HL] = DE, this sets the initial stack pointer
	RepointStruct HL, task_sp+2, task_rombank
	ld A, C
	ld [HL+], A ; [HL] = C, this sets the initial ROM bank
	RepointStruct HL, task_rombank+1, task_rambank
	xor A
	ld [HL+], A ; [HL] = 0, this sets the initial RAM bank
	RepointStruct HL, task_rambank+1, task_waiter
	dec A ; A = ff
	ld [HL], A ; [HL] = ff, this says the task is initially not waiting for any waiter
	jp SchedAddTask ; schedule new task to run and return


; Create a new task with entry point in DE, ROM bank C (or 0) and a stack allocated from dynamic memory.
; Returns the new task id in B, or 255 if no task could be allocated.
TaskNewDynStack::
	call TaskFindNextFree ; B = new task id or 255
	ld A, B
	cp $ff
	ret z ; if B = 255, exit early with failure
	push DE
	ld D, B ; this sets task ownership of allocated mem
	ld E, C ; storing B and C in D and E is faster than push and pop
	ld B, DYN_MEM_STACK_SIZE
	ld HL, GeneralDynMem
	call DynMemAlloc ; allocate stack in the name of task D, put in HL
	ld B, D
	ld C, E ; restore B and C
	pop DE
	ld A, H
	or L ; H or L -> set Z if HL == $0000
	jr nz, .nofail
	; return failure since we couldn't allocate a stack
	ld B, $ff
	ret
.nofail
	; HL points to the base of the new stack, but stacks grow down,
	; we want to give the top of the stack
	ld A, DYN_MEM_STACK_SIZE
	LongAddToA HL, HL ; HL += stack size
	jr TaskNewWithID ; tail call


; Task-callable versions of TaskNew family
T_TaskNewWithStack::
	call T_DisableSwitch
	call TaskNewWithStack
	jp T_EnableSwitch

T_TaskNewDynStack::
	call T_DisableSwitch
	call TaskNewDynStack
	jp T_EnableSwitch


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
	ld A, [HL+]
	ld E, A
	ld D, [HL] ; DE = return address. Note it's backwards because stack grows down.
	; Now we can save SP and switch stacks
	ld HL, SP+0
	ld B, H
	ld C, L ; BC = SP
	ld A, [CurrentTask]
	LongAddToA TaskList+task_sp, HL ; HL = TaskList + CurrentTask + task_sp = &(TaskList[CurrentTask].task_sp)
	; Save SP to task struct
	ld A, B
	ld [HL+], A
	ld [HL], C
	; Load core stack
	ld SP, CoreStack
	; Return to saved address
	ld H, D
	ld L, E ; HL = return address
	jp HL


; Load task state and return into the task.
; Does not return to called function - in fact, it ignores the current stack completely.
; Takes task ID to load in A.
TaskLoad::
	ld [CurrentTask], A
	LongAddToA TaskList+task_sp, HL ; HL = TaskList + A + task_sp = &(TaskList[A].task_sp)
	; BC = [HL] = stored stack pointer
	ld A, [HL+]
	ld B, A
	ld A, [HL+]
	ld C, A
	; Set ROM and RAM banks, if any
	RepointStruct HL, task_sp+2, task_rombank
	ld A, [HL+]
	and A
	jr z, .noROM
	ld [CurrentROMBank], A
	SetROMBank
	xor A
.noROM
	RepointStruct HL, task_rombank+1, task_rambank
	add [HL]
	jr z, .noRAM
	ld [CurrentRAMBank], A
	SetRAMBank
.noRAM
	; set stack pointer
	ld H, B
	ld L, C
	ld SP, HL
	; Set up time slice interval and enable switch.
	; EnableSwitch clobbers A, so we have to do this now.
	; It should be safe even if we switch out here, since we will cleanly return to here,
	; then continue on to finish the first switch.
	ld A, SWITCH_TIME_INTERVAL
	ld [SwitchTimer], A
	EnableSwitch
	; restore regs
	pop HL
	pop DE
	pop BC
	pop AF
	; The SaveTask process leaves some junk on the stack, skip it.
	; Note we can't use ADD SP, 2 here as this would change flags
	inc SP
	inc SP
	; at this point, the top of the user's stack should be the PC to return to
	ret


; Voluntarily give up task execution. Allows other tasks to run and returns some time later.
; Clobbers A.
T_TaskYield::
	DisableSwitch
	; fallthrough
; For use by core code to suspend currently running task, but keep it runnable.
TaskYield::
	call TaskSave ; switch onto core stack
	ld A, [CurrentTask]
	ld B, A
	call SchedAddTask ; re-enqueue task to run again
	jp SchedLoadNext ; does not return


; Temporarily disable time-share switching (calling T_TaskYield is still ok),
; allowing critical sections without disabling interrupts entirely.
; Clobbers A.
T_DisableSwitch::
	DisableSwitch
	ret


; Re-enable time-share switching after a call to T_DisableSwitch.
; If a switch attempt was missed, this will trigger an immediate switch.
; Clobbers A.
T_EnableSwitch::
	ld A, [Switchable]
	cp 2
	jp z, TaskYield ; will return to our caller later
	EnableSwitch
	ret


; This is the only safe way for a task to switch ROM banks.
; Sets current ROM bank for this task to C.
; It saves state so that the task's bank can be set on each TaskLoad.
; Clobbers A, HL
T_SetROMBank::
	ld A, [CurrentTask]
	LongAddToA TaskList+task_rombank, HL ; HL = TaskList + CurrentTask + task_rombank = &(TaskList[CurrentTask].task_rombank)
	ld [HL], C
	ld A, C
	ld [CurrentROMBank], A
	SetROMBank
	ret


; This is the only safe way for a task to switch RAM banks.
; Sets current RAM bank for this task to C.
; It saves state so that the task's bank can be set on each TaskLoad.
; Clobbers A, HL
T_SetRAMBank::
	ld A, [CurrentTask]
	LongAddToA TaskList+task_rambank, HL ; HL = TaskList + CurrentTask + task_rambank = &(TaskList[CurrentTask].task_rambank)
	ld [HL], C
	ld A, C
	ld [CurrentRAMBank], A
	SetRAMBank
	ret
