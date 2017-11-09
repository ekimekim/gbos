include "task.asm"
include "hram.asm"

; A waiter is a data structure which allows a task to sleep until
; the waiter is 'woken' - many tasks can sleep on the same waiter
; and will all be woken (made runnable) when the waiter is woken.
; Waiters are thread-safe via use of the task switching lock,
; as long as the T_ methods are used.
; Waiters used in the context of an interrupt handler should take care
; and disable interrupts during operations.

; --- Waiter struct ---
; First form: magic value and single task id
RSRESET
waiter_magic rb 1 ; 0 or 1 indicates first form. 0 indicates no tasks.
waiter_task rb 1 ; task id of waiting task if magic == 1
WAITER_SIZE rb 0
; Second form: RAM address of dynamically allocated MAX_TASKS-sized array of waiting task ids.
; This array is ff-terminated.
; Note since RAM addresses can't start with $00 or $01 this is distinguishable from first form.
RSRESET
waiter_addr rw 1
_WAITER_SIZE_FORM2 rb 0

IF WAITER_SIZE != _WAITER_SIZE_FORM2
FAIL "Waiter struct forms different sizes: {WAITER_SIZE} vs {_WAITER_SIZE_FORM2}"
ENDC

; Declare a new waiter.
WaiterDeclare: MACRO
	ds WAITER_SIZE
	ENDM

; Initialize a waiter at immediate address \1.
; Clobbers A.
WaiterInit: MACRO
	xor A
	ld [\1 + waiter_magic], A
	ENDM

; Add task \2 (not A or HL) to waiter \1. This is mostly for OS usage or internals,
; normal users should be using T_WaiterWait instead.
; Outputs A = 0 on success, ff on failure.
WaiterAddTask: MACRO
	ld A, [\1 + waiter_magic]
	and A ; set z if A == 0
	jr nz, .not_empty\@
.empty\@
	inc A ; A = 1
	ld [\1 + waiter_magic], A
	ld A, \2
	ld [\1 + waiter_task], A
	xor A
	jr .end\@
.not_empty\@
	dec A ; set z if A == 1
	jr nz, .add_to_array\@
.one_to_many\@
	push HL
	push BC
	push DE
	ld HL, GeneralDynMem
	ld D, $fe ; assigns memory ownership to the OS itself
	ld B, MAX_TASKS + 1 ; +1 so we always have room for sentinel
	call DynMemAlloc ; HL = allocated memory, or 0000 on failure.
	pop DE
	ld A, H
	and A ; set z if H == 0, which means HL == 0000 since H = 0 is otherwise invalid.
	jr nz, .no_fail\@
	pop BC
	pop HL
	dec A ; A = ff
	jr .end\@
.no_fail\@
	ld A, [\1 + waiter_task]
	ld B, A
	ld A, H
	ld [\1 + waiter_addr], A
	ld A, L
	ld [\1 + waiter_addr + 1], A
	; TODO UPTO old task id is in B, new array is in HL and uninitialized
	ld A, B
	ld [HL+], A ; write existing task id
	pop BC
	ld A, \2
	ld [HL+], A ; write new task id
	ld A, $ff
	ld [HL], A ; write terminating ff
	pop HL
	xor A
	jr .end\@
.add_to_array\@
	inc A ; reverse the dec from earlier
	push HL
	ld H, A
	ld A, [\1 + waiter_addr + 1]
	ld L, A ; HL = addr of array
	; loop until we find the terminating value
.find_end_loop\@
	ld A, [HL+]
	inc A ; set z if A was $ff
	jr nz, .find_end_loop\@
	; now HL points one past the sentinel value, and A == 0
	dec A ; A = $ff
	ld [HL-], A ; set new sentinel and go back one
	ld A, \2
	ld [HL], A ; set new task id
	pop HL
	xor A
.end\@
	ENDM

; Wait (sleep current task) until waiter \1 is woken.
; Outputs A = 0 on success or $ff on failure.
WaiterWait: MACRO
	WaiterAddTask \1, [CurrentTask]
	ENDM

; As per WaiterWait but task-callable.
T_WaiterWait: MACRO
	call T_DisableSwitch
	WaiterWait \1
	call T_EnableSwitch
	ENDM
