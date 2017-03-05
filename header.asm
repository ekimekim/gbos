
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
	reti
section "Serial Interrupt handler", ROM0 [$58]
; Serial transfer is complete
IntSerial::
	reti
section "Joypad Interrupt handler", ROM0 [$60]
; Change in joystick state
IntJoypad::
	reti

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
