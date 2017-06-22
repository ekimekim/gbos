include "hram.asm"

; Joypad input is not sampled under normal circumstances to save CPU time.
; We set up a JoyInt to fire if any button is pressed.
; When a button is pressed, we take a sample immediately,
; and then every 16 timer interrupts (~16ms) thereafter.


SECTION "Joypad management methods", ROM0


JoyInit::
	xor A
	ld [JoyState], A
	ret


JoyInt::
	reti ; TODO stub


JoyReadState::
	ret ; TODO stub
