include "waiter.asm"
include "task.asm"
include "hram.asm"
include "longcalc.asm"

; In addition to the waiter macros in include/waiter.asm,
; these methods take the waiter address in HL.

SECTION "Waiter methods", ROM0


; Wait on waiter in HL, putting this task to sleep until it is woken.
; Clobbers A, D, E, H, L
WaiterWait::
	call T_DisableSwitch
	RepointStruct HL, 0, waiter_count
	inc [HL]
	RepointStruct HL, waiter_count, waiter_min_task
	ld A, [CurrentTask]
	cp [HL] ; set c if current task < waiter's existing min task
	jr nc, .notlesser
	ld [HL], A
.notlesser
	RepointStruct HL, waiter_min_task, 0
	ld D, H
	ld E, L ; DE = HL = waiter address
	ld A, [CurrentTask]
	LongAddToA TaskList+task_waiter, HL ; HL = &TaskList[Current Task].task_waiter
	ld A, D
	ld [HL+], A
	ld [HL], E ; task_waiter = DE
	; In unit tests, we don't want to pass control to the scheduler. Instead, just return.
IF DEF(_IS_UNIT_TEST)
	ret
ENDC
	call TaskSave
	jp SchedLoadNext ; does not return


; This function is for internal use by the WaiterWake and WaiterWakeHL macros,
; do not use it directly.
; Does the actual work of waking waiters.
; Re-checks count is not zero as the prev check in the macros didn't hold switch lock,
; so it might have changed.
; HL points to waiter.
; Clobbers all.
_WaiterWake::
	call T_DisableSwitch
	RepointStruct HL, 0, waiter_count
	ld A, [HL]
	and A ; set z if A == 0
	jr z, .finish
	ld C, A ; C = count of things to wake
	RepointStruct HL, waiter_count, 0
	ld D, H
	ld E, L ; DE = HL = waiter address
	RepointStruct HL, 0, waiter_count
	xor A
	ld [HL+], A ; set count to 0
	RepointStruct HL, waiter_count + 1, waiter_min_task
	ld B, [HL] ; B = min task
	dec A ; A = ff
	ld [HL], A ; set min task id to ff, waiter is now cleared
	ld A, B
	LongAddToA TaskList+task_sp, HL ; HL = &TaskList[min task].task_sp
	; Starting at min task and proceeding until either we wake count tasks, or we hit end of task list.
	; C contains things left to find, B contains current task id (stop when we hit MAX_TASKS * TASK_SIZE),
	; DE is addr to compare to and HL is our pointer.
.loop

	; A task doesn't clear its waiter field on death, so we need to check its task_sp is non-zero
	; so we know it's a valid entry.
	ld A, [HL+]
	and A
	jr nz, .valid
	LongAdd HL, TASK_SIZE-1, HL ; HL += TASK_SIZE - 1
	jr .skip
.valid

	; Advance to task bank fields
	RepointStruct HL, task_sp + 1, task_rambank
	; Check ram bank, if needed.
	; This seems kinda wasteful to determine every time but we're out of regs.
	; We determine this from top 4 bits:
	;  101x - SRAM bank (currently ignored since we assume no sram switching right now)
	;  1100 - WRAM0 (no bank to check)
	;  1101 - WRAMX (check ram bank)
	;  1111 - HRAM (no bank to check)
	ld A, D
	rla
	rla ; this puts 2nd from top bit into carry. 0 -> SRAM, 1 -> WRAM or HRAM
	jr c, .sram
	and %11000000 ; select top 2 bits. 00 -> WRAM0, 01 -> WRAMX, 11 -> HRAM
	cp %01000000 ; set z if WRAMX
	jr nz, .bank_is_good
.wramx
	ld A, [CurrentRAMBank]
	cp [HL] ; compare to task_rambank, set z if match
	jr z, .bank_is_good
	RepointStruct HL, task_rambank, TASK_SIZE + task_sp ; Point to next task and continue
	jr .skip
.sram
	; TODO SRAM checking goes here once we track that, for now assume good
.bank_is_good

	; Advance to task_waiter
	RepointStruct HL, task_rambank, task_waiter
	; Check it against address
	ld A, [HL+]
	cp D ; set z if upper half of address matches
	ld A, [HL+]
	jr nz, .next ; skip forward if D didn't match
	cp E ; set z if lower half matches
	jr nz, .next ; skip forward if E didn't match
	; Address matches: Wake this task and decrement count, check for count == 0 exit
	push HL ; save pointer to task_waiter+2
	RepointStruct HL, task_waiter + 2, task_waiter ; HL = task_waiter
	ld [HL], $ff ; set task as having no waiter
	call SchedAddTask ; schedule task
	pop HL ; restore HL = task_waiter + 2
	dec C ; decrement count, set z if count == 0
	jr z, .finish ; if count == 0, break
.next
	; Go to next task in B, advance HL to next task's task_sp, check for end of task list
	RepointStruct HL, task_waiter + 2, TASK_SIZE + task_sp
.skip
	ld A, B
	add TASK_SIZE
	ld B, A
	cp MAX_TASKS * TASK_SIZE ; set c if B is still within task list
	jr c, .loop
.finish
	jp T_EnableSwitch ; tail call
