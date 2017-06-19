include "longcalc.asm"
include "ioregs.asm"
include "hram.asm"

SECTION "test joypad ram", WRAM0

NumJoyInts:
	db

SECTION "test joypad code", ROM0

TestJoyPadInit::
	xor A
	ld [NumJoyInts], A
	ld A, $10 ; 0, $10, $20 or $30
	ld [JoyIO], A
	ret

ToHexDigit: MACRO
; assuming A is in range 0-15, outputs A = ascii '0' to 'F'
	cp 10
	jr c, .skip\@
	add 7
.skip\@
	add 48
	ENDM

Wait: MACRO
	REPT \1
	nop
	ENDR
	ENDM

TestJoyInt::
	; This fires on the joypad interrupt. it does two things:
	; - increments a number of 'fired joypad interrupts', and displays it on screen
	; - displays the last 8 seen states of the joypad on screen
	push AF
	push BC
	push DE
	push HL

	ld HL, InterruptsEnabled
	res 4, [HL] ; disable joypad int
	DisableSwitch
	ei

	ld A, [NumJoyInts]
	inc A
	ld [NumJoyInts], A
	ld B, A
	and $0f
	ToHexDigit
	ld C, A
	ld DE, 0
	call GraphicsTryWriteTile
	ld A, B
	and $f0
	swap A
	ToHexDigit
	ld C, A
	ld DE, 1
	call GraphicsTryWriteTile

	ld A, B
	and $07 ; mod 8
	add 1 ; A = row to write to
	ld D, 0
	ld E, A ; DE = A
	REPT 5
	LongShiftL D, E ; shift 5, ie. DE *= 32
	ENDR

	ld A, JoySelectDPad
	ld [JoyIO], A
	Wait 4
	ld A, [JoyIO]
	and $0f
	ToHexDigit
	ld C, A
	ld A, JoySelectButtons
	ld [JoyIO], A
	call GraphicsTryWriteTile
	ld A, [JoyIO]
	and $0f
	ToHexDigit
	ld C, A
	call GraphicsTryWriteTile

	ld HL, InterruptsEnabled
	set 4, [HL] ; enable joypad int

	EnableSwitch

	pop HL
	pop DE
	pop BC
	pop AF
	ret
