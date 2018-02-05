IF !DEF(_G_WAITER)
_G_WAITER EQU "true"

include "longcalc.asm"

; Waiters provide a primitive for putting tasks to sleep until some other task wishes to wake them.
; Use these methods (apart from the Declare methods) by giving the first arg as the waiter's label.
; Waiters are switch-safe by default but not interrupt-safe. For core usage with interrupt handlers,
; IntSafeWaiters must be used.

; --- Waiter struct ---
RSRESET
waiter_count rb 1 ; How many tasks are currently waiting on this waiter.
                  ; This is used to avoid unneeded work, mostly for when count is 0 or 1.
waiter_min_task rb 1 ; Minimum task id that may be waiting on this waiter.
                     ; Again, this saves time by letting us jump straight to the task in question.
WAITER_SIZE rb 0

; --- IntSafeWaiter struct ---
RSRESET
; Flag meanings:
;  0: Default state, nothing is happening
;  1: Set to 1 while a task is in the process of becoming waiting on this waiter
;  2: Set to 2 by interrupt handler if it calls WaiterWake while flag is at 1.
;     This indicates to the task that it must roll back its wait and call Wake.
isw_flag rb 1
isw_waiter rb WAITER_SIZE ; Wrapped waiter
ISW_SIZE rb 0

; Declare memory for a waiter
DeclareWaiter: MACRO
	ds WAITER_SIZE
ENDM

DeclareIntSafeWaiter: MACRO
	ds ISW_SIZE
ENDM

; Initialize the waiter at immediate \1. Clobbers A.
WaiterInit: MACRO
	xor A
	ld [\1 + waiter_count], A
	dec A ; A = ff
	ld [\1 + waiter_min_task], A
ENDM

; Be careful to ensure int-safe waiters are not used by interrupts before they're fully
; initialized.
IntSafeWaiterInit: MACRO
	xor A
	ld [\1 + isw_flag], A
	WaiterInit (\1 + isw_waiter)
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
	call T_DisableSwitch
	call _WaiterWake
	call T_EnableSwitch
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
	call T_DisableSwitch
	call _WaiterWake
	call T_EnableSwitch
	pop BC
	pop DE
	pop HL
.zero\@
	RepointStruct HL, waiter_count, 0
ENDM

; Safely checks a condition by calling \2.
; If carry is set (mnumonic: "carry on") on return from \2, we return immediately.
; Otherwise, we wait on IntSafeWaiter \1.
; In either case, nothing will be clobbered between returning from \2 and returning from this function.
; This function is needed as otherwise the condition could change and the waiter woken
; in between checking your condition and calling IntSafeWaiterWait, leaving you waiting forever.
IntSafeWaiterCheckOrWait: MACRO
	push AF
	call T_DisableSwitch ; prevent switching in order to safely touch the isw flag
	ld A, 1
	ld [(\1) + isw_flag], A ; set flag to 1, so we will be informed if wake would occur
	pop AF
	call (\2) ; set c if we shouldn't wait
	; Note we must still call _IntSafeWaiterMaybeWait even if c is set, in order to safely
	; clear the isw_flag.
	push HL
	ld HL, (\1)
	call _IntSafeWaiterCheckOrWait
	pop HL
ENDM

; Safely wakes waiters of IntSafeWaiter \1.
; Clobbers A.
IntSafeWaiterWake: MACRO
	ld A, [(\1) + isw_flag]
	and A ; set z if A == 0
	jr z, .wake\@
	; A == 1 or 2, set flag to 2 to indicate a wake was missed
	ld A, 2
	ld [(\1) + isw_flag], A
	jr .end\@
.wake\@
	WaiterWake ((\1) + isw_waiter)
.end\@
ENDM

ENDC
