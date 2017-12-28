include "hram.asm"

; Warning: each of these sections can only be 8b long!
section "Restart handler 0", ROM0 [$00]
Restart0::
	jp HaltForever
section "Restart handler 1", ROM0 [$08]
Restart1::
	jp HaltForever
section "Restart handler 2", ROM0 [$10]
Restart2::
	jp HaltForever
section "Restart handler 3", ROM0 [$18]
Restart3::
	jp HaltForever
section "Restart handler 4", ROM0 [$20]
Restart4::
	jp HaltForever
section "Restart handler 5", ROM0 [$28]
Restart5::
	jp HaltForever
section "Restart handler 6", ROM0 [$30]
Restart6::
	jp HaltForever
section "Restart handler 7", ROM0 [$38]
Restart7::
	jp HaltForever

; Warning: each of these sections can only be 8b long!
section "VBlank Interrupt handler", ROM0 [$40]
; triggered upon VBLANK period starting
IntVBlank::
	jp GraphicsVBlank
section "LCDC Interrupt handler", ROM0 [$48]
; Also known as STAT handler
; LCD controller changed state
IntLCDC::
	reti
section "Timer Interrupt handler", ROM0 [$50]
; A configurable amount of time has passed
IntTimer::
	; This is a jr instruction for speed, but the assembler isn't smart enough to allow it.
	; So, given the hard-coded assuption that TimerHandler is at $68, we hand-code a instruction.
	; $68 - $50 = $18, so we encode "jr $18".
	; Opcode is $18 nn where nn is signed byte (jump distance - 2), so we encode $18 $16.
	db $18, $16 ; jr $18 = jr TimerHandler
section "Serial Interrupt handler", ROM0 [$58]
; Serial transfer is complete
IntSerial::
	reti
section "Joypad Interrupt handler", ROM0 [$60]
; Change in joystick state
IntJoypad::
	jp JoyInt

; Since jr is faster than jp but short-range, this code must be close to int handlers.
section "Extended handler code", ROM0 [$68]

; TimerHandler MUST be at $68, or you need to change the jr instruction at IntTimer
TimerHandler::
	; our purpose here is to make it as fast as possible for the far-most-common case
	; where we only increment the least signifigant byte
	; current cycle count, assuming no switch or joy, not counting anything /256 or smaller:
	; (before nocarry: 17 + 11/16) + (after nocarry: 15) = ~32.7 on average
	; Since it runs ~ every 1000 cycles, this means a min overhead of ~32.7/1000 = ~3.27%
	; Theoretical limit for jr (from interrupt handle addr) + push one + pop one + reti = 14
	; To do better than this (1.4%) we'd need to lower Uptime's granularity.
	push AF
	; Increment 4-byte number
	ld A, [Uptime]
	inc A
	ld [Uptime], A
	and $0f
	jr nz, .nocarry ; if lower byte != 0, we're done with incrementing.
	; otherwise maybe do joypad scan, then check upper byte
	ld A, [JoyState]
	and A
	jr z, .nojoy
	call JoyReadState
.nojoy
	ld A, [Uptime]
	and A
	jr nz, .nocarry ; if the original byte we were talking about is 0, continue. else don't.
	ld A, [Uptime+1]
	inc A
	ld [Uptime+1], A
	jr nz, .nocarry
	ld A, [Uptime+2]
	inc A
	ld [Uptime+2], A
	jr nz, .nocarry
	ld A, [Uptime+3]
	inc A
	ld [Uptime+3], A
.nocarry
	ld A, [SwitchTimer]
	dec A ; set z if we're ready to switch
	ld [SwitchTimer], A
	jr nz, .ret ; if we aren't switching, return
	; task switch if applicable
	ld A, [Switchable]
	and A
	jr z, .switch
	; No switch, leave a marker. Since SwitchTimer is now 0, it will underflow and give us 256 loops
	; before we'll try to switch again. This is fine because the marker will cause a switch as soon
	; as the task enables switching.
	ld A, 2
	ld [Switchable], A
.ret
	pop AF
	reti
.switch
	DisableSwitch
	ei ; It's now safe - we can't switch out but we're done with int-critical operations
	pop AF
	; note we've been careful to reinstate all clobbered regs before calling TaskYield
	jp TaskYield ; does not return


section "Core Utility", ROM0
HaltForever::
	halt
	; halt can be recovered from after an interrupt or reset, so halt again
	jp HaltForever

section "Header", ROM0 [$100]
; This must be nop, then a jump, then blank up to 150
_Start:
	nop
	jp Start
_Header::
	ds 76 ; Linker will fill this in
