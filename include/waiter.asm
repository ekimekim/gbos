IF !DEF(_G_WAITER)
_G_WAITER EQU "true"

include "longcalc.asm"

; Waiters provide a primitive for putting tasks to sleep until some other task wishes to wake them.
; Use these methods (apart from the Declare methods) by giving the first arg as the waiter's label.

; --- Waiter struct ---
RSRESET
waiter_count rb 1 ; How many tasks are currently waiting on this waiter.
                  ; This is used to avoid unneeded work, mostly for when count is 0 or 1.
waiter_min_task rb 1 ; Minimum task id that may be waiting on this waiter.
                     ; Again, this saves time by letting us jump straight to the task in question.

WAITER_SIZE rb 0

; Declare memory for a waiter
DeclareWaiter: MACRO
	ds WAITER_SIZE
ENDM

; Initialize the waiter at immediate \1. Clobbers A.
WaiterInit: MACRO
	xor A
	ld [\1 + waiter_count], A
	dec A ; A = ff
	ld [\1 + waiter_min_task], A
ENDM

; As WaiterInit, but initializes waiter pointed at by HL instead. Clobbers A, HL.
WaiterInitHL: MACRO
	xor A
	ld [HL+], A
	dec A ; A = ff
	ld [HL], A
ENDM

; WaiterWake wakes all tasks that are waiting on waiter at immediate \1.
; WaiterWake is done here as an inline macro for speed in the common case of count = 0,
; but falls back to a method for the longer case.
; Note we don't disable switching, so state may change between our check and calling
; the real function. For this reason the real function double checks its still valid.
; Clobbers A. (The actual impl clobbers more, but we only push if non-zero)
WaiterWake: MACRO
	ld A, [\1 + waiter_count]
	and A ; set z if A == 0
	jr z, .zero\@
	push HL
	push DE
	push BC
	ld HL, \1
	call _WaiterWake
	pop BC
	pop DE
	pop HL
.zero\@
ENDM

; As WaiterWake but wakes waiter pointed at by HL instead.
; Clobbers A.
WaiterWakeHL: MACRO
	RepointStruct HL, 0, waiter_count
	ld A, [HL]
	and A ; set z if A == 0
	jr z, .zero\@
	push HL
	push DE
	push BC
	call _WaiterWake
	pop BC
	pop DE
	pop HL
.zero\@
	RepointStruct HL, waiter_count, 0
ENDM

ENDC
