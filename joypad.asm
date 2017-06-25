include "hram.asm"
include "ioregs.asm"
include "ring.asm"

; Joypad input is not sampled under normal circumstances to save CPU time.
; We set up a JoyInt to fire if any button is pressed.
; When a button is pressed, we take a sample immediately, disable the interrupt,
; and then poll every 16 timer interrupts (~16ms) thereafter.
; When we see all buttons are released, we re-enable the interrupt and stop polling.
; See timer interrupt for more on when polling occurs.

; We munge JoyIO to a (hopefully unused!) HRAM address when running in unit tests,
; so that we can set the inputs for specific tests. The code below puts in calls
; to a _UnitTestUpdateJoyIO macro below after writing to JoyIO so that the unit test
; can respond correctly to selecting lines.
IF DEF(_IS_UNIT_TEST)
PURGE JoyIO
JoyIO EQU $fffe
ELSE
_UnitTestUpdateJoyIO: MACRO
ENDM
ENDC


JOY_QUEUE_SIZE EQU 63


SECTION "Joypad RAM", WRAM0

; Ring containing an entry for every state change in the Joypad input.
; Each byte encodes full joypad state as per JoyState.
JoyQueue::
	RingDeclare JOY_QUEUE_SIZE


SECTION "Joypad management methods", ROM0


JoyInit::
	RingInit JoyQueue
	xor A
	ld [JoyState], A ; Select both input lines
	ld HL, InterruptsEnabled
	set 4, [HL] ; Enable joypad interrupt
	ret


JoyInt::
	push AF
	call JoyReadState
	pop AF
	reti


; Read current joypad state, and if it differs from previous, emit an event
; and manage interrupt state.
; Clobbers AF. Assumes interrupts are disabled.
JoyReadState::
	ld A, JoySelectDPad
	ld [JoyIO], A
	_UnitTestUpdateJoyIO
	push BC
	ld C, JoyIO & $ff
	ld A, [C] ; it's been 6 cycles, should be long enough
	ld B, A
	ld A, JoySelectButtons
	ld [C], A
	_UnitTestUpdateJoyIO
	ld A, B
	or $f0 ; we're gonna NOT this later, so this is basically an "and $0f"
	swap A
	ld B, A
	ld A, [C] ; 6 cycles later
	or $f0
	and B ; again, since we're working with an inverse, this is like "or B"
	cpl ; now A = (DPad, Buttons)
	; compare with prev state
	ld B, A
	ld A, [JoyState]
	cp B
	jr z, .ret ; if equal, no further action needed

	; we may need to affect interrupts:
	; 0 -> !0: disable interrupt
	; !0 -> 0: enable interrupt
	; we also need to update the state and push it to the event queue
	push HL
	and A ; set z if prev state == 0
	jr nz, .not_prev_zero
	; prev state was 0, so interrupt is enabled, we need to disable it since we'll be polling now
	ld HL, InterruptsEnabled
	res 4, [HL] ; disable joypad interrupt
	jr .not_now_zero
.not_prev_zero
	ld A, B
	and A ; set z if new state == 0
	jr nz, .not_now_zero
	; New state is 0, so polling will cease, we need to re-enable interrupt.
	; To avoid a race between reading a 0 above and a button subsequently being pressed,
	; we do something weird - we unselect both JoyIO lines, reset InterruptFlags, then
	; select both lines. The latter needs to be done anyway, and unselecting them first means
	; that, if any button is being pressed, it will trigger an interrupt.
	ld A, %00110000 ; deselect both lines
	ld [C], A ; note C is still set as above
	ld HL, InterruptFlags
	res 4, [HL] ; clear any pending joypad interrupt
	ld HL, InterruptsEnabled
	set 4, [HL] ; enable joypad interrupts
	xor A
	ld [C], A ; select both lines, so subsequent interrupts will fire for either dpad or buttons
.not_now_zero

	ld A, B
	ld [JoyState], A

	RingPush JoyQueue, JOY_QUEUE_SIZE, B, C ; push B to JoyQueue, clobbers C
	; Note above may fail, but we don't care either way - we'll just drop inputs if queue is full.

	pop HL
.ret
	pop BC
	ret
