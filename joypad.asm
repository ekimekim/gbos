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
.not_now_zero

	ld A, B
	ld [JoyState], A

	RingPush JoyQueue, JOY_QUEUE_SIZE, B, C ; push B to JoyQueue, clobbers C
	; Note above may fail, but we don't care either way - we'll just drop inputs if queue is full.

	pop HL
.ret
	xor A
	ld [JoyIO], A ; select both lines, so subsequent interrupts will fire for either dpad or buttons
	pop BC
	ret


; Get the next event from the JoyQueue, if any.
; Puts event in B and unsets z flag, or sets z flag if no event available.
; Clobbers A, H, L
JoyTryGetEvent::
	RingPop JoyQueue, JOY_QUEUE_SIZE, B
	ret


; As JoyTryGetEvent, but callable from tasks
T_JoyTryGetEvent::
	call T_DisableSwitch
	call JoyTryGetEvent
	push AF ; preserve A and z flag state over call to T_EnableSwitch
	call T_EnableSwitch
	pop AF
	ret


; As T_JoyTryGetEvent, but blocks until an event is available.
; Note: Since this may block, there is no non-T_ version
T_JoyGetEvent::
	; TODO for now, busy loop. Use something smarter later.
.loop
	call T_JoyTryGetEvent
	jp z, .loop ; try again if not success
	ret


; Takes previous joypad state in C, and scans joypad events until it encounters a button press.
; It will then return new state in C and a bitmask of pressed buttons in A.
; The A byte will contain a 1 bit for each button which became pressed.
; In most cases this will only be one bit, but not always.
; For example, if up+left are pressed at the exact same time, the resulting byte will be %01100000.
; This is a very tight window and you should NOT use this to detect when to do "both pressed" behaviours.
; Instead, you should take each bit set in each result as an independent press event.
; Note that since this may need to get many JoyQueue events and blocks if none are available,
; there is no non-T_ version.
; Clobbers HL.
T_JoyGetPress::
.loop
	call T_JoyGetEvent ; B = next event, possibly blocking
	ld A, C
	cpl
	and B ; A = new & !old, ie. bit has gone 0->1
	ld C, B ; regardless of whether we're done, set saved state = new state
	jr z, .loop ; note the and above also sets z flag depending on if anything has been pressed
	; if we've reached here, A contains pressed bits and C contains new state
	ret
