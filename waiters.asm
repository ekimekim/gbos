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
	call WaiterDeterminant ; DE = determinant
	ld A, [CurrentTask]
	LongAddToA TaskList+task_waiter, HL ; HL = &TaskList[Current Task].task_waiter
	ld A, D
	ld [HL+], A
	ld [HL], E ; task_waiter = DE
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
	call WaiterDeterminant ; DE = determinant
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
	; DE is determinant to compare to and HL is our pointer.
.loop
	; A task doesn't clear its waiter field on death, so we need to check its task_sp is non-zero
	; so we know it's a valid entry.
	ld A, [HL+]
	and A
	jr nz, .valid
	LongAdd HL, TASK_SIZE-1, HL ; HL += TASK_SIZE - 1
	jr .skip
.valid
	; Advance to task_waiter
	RepointStruct HL, task_sp, task_waiter
	; Check it against determinant
	ld A, [HL+]
	cp D ; set z if upper half of determinant matches
	ld A, [HL+]
	jr nz, .next ; skip forward if D didn't match
	cp E ; set z if lower half matches
	jr nz, .next ; skip forward if E didn't match
	; Determinant matches: Wake this task and decrement count, check for count == 0 exit
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


; Calculate determinant of waiter in HL, put result in DE.
; See include/waiter.asm for description of calculating determinant.
; Clobbers A.
WaiterDeterminant:
	ld D, H
	ld E, L
	LongShiftR DE ; DE = HL >> 1
	ld A, D
	and $f0 ; grab top 3 bits of address
	cp %01100000 ; top 3 bits == 110 (z) means WRAM, < 110 (c) means SRAM, > (neither) means HRAM
	jr z, .sram
	jr c, .wram
.hram
	ld D, %11000000 ; DE = 1100 0000 aaaa aaaa
	ret
.wram
	ld A, D
	and %00000111
	ld D, A ; mask out top 5 bits of D, DE = 0000 0aaa aaaa aaaa
	ld A, [CurrentRAMBank] ; A = 0000 0bbb since ram bank is 0-7
	bit 4, H ; set z if 4th bit of HL set, ie. if in WRAMX, not WRAM0
	jr z, .wramx
	xor A ; force bank = 0 for WRAM0 addrs
.wramx
	swap A ; A = 0bbb 0000
	inc A ; A = 0bbb 0001
	rrca ; A = 10bb b000
	or D
	ld D, A ; DE = 10bb baaa aaaa aaaa
	ret
.sram
	LongShiftR DE ; DE = 00aa aaaa aaaa aaaa
	ld A, D
	and %00000111
	ld D, A ; mask out top 5 bits of D, DE = 0000 0aaa aaaa aaaa
	; TODO need to get SRAM bank here, currently never saved or set so assume 0
	xor A ; A = sram bank = 0000 bbbb since sram bank is 0-15
	swap A ; A = bbbb 0000
	rrca ; A = 0bbb b000
	or D
	ld D, A ; DE = 0bbb baaa aaaa aaaa
	ret
