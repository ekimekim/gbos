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
	reti
section "LCDC Interrupt handler", ROM0 [$48]
; Also known as STAT handler
; LCD controller changed state
IntLCDC::
	reti
section "Timer Interrupt handler", ROM0 [$50]
; A configurable amount of time has passed
IntTimer::
	jp TimerHandler ; This could be a jr instruction (faster), but the assembler isn't smart enough
section "Serial Interrupt handler", ROM0 [$58]
; Serial transfer is complete
IntSerial::
	reti
section "Joypad Interrupt handler", ROM0 [$60]
; Change in joystick state
IntJoypad::
	reti

; Since jr is faster than jp but short-range, this code must be close to int handlers.
section "Extended handler code", ROM0 [$68]

TimerHandler::
	; our purpose here is to make it as fast as possible for the far-most-common case
	; where we only increment the least signifigant byte
	push AF
	ldh A, [Uptime+3]
	inc A
	ldh [Uptime+3], A
	and $7 ; set z every 8th increment
	jr nz, .ret
	push HL
	ld HL, Uptime+3
	add [HL] ; set z if [Uptime+3] is 0
	jr nz, .nocarry
	dec HL ; Uptime+2
	inc [HL]
	jr nc, .nocarry
	dec HL ; Uptime+1
	inc [HL]
	jr nc, .nocarry
	dec HL ; Uptime
	inc [HL]
.nocarry
	; task switch if applicable
	ld A, [Switchable]
	and A
	pop HL
	jr z, .switch
	; no switch, leave a marker
	ld A, 2
	ld [Switchable], A
.ret
	pop AF
	reti
.switch
	DisableSwitch
	ei ; It's now safe - we can't switch out but we're done with int-critical operations
	pop AF
	; note we've been careful to reinstate all clobbered regs before calling TaskSave
	call TaskSave
	jp SchedLoadNext ; does not return


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
