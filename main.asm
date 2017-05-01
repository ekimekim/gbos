include "constants.asm"


SECTION "Core Stack", WRAM0

CoreStackBase:
	ds CORE_STACK_SIZE


Section "Core Functions", ROM0


; Temporary code for testing task switching
Start::


Task1::
	ld A, 1
	ld B, 2
	ld C, 3
	ld D, 4
	ld E, 5
	ld HL, $face
.loop
	inc A
	jp .loop


Task2::
	ld B, 10
	call Fib
	call HaltForever

; return Bth fibbonacci number in DE
Fib:
	ld A, B
	cp 2
	jr nc, .noUnderflow
	ld D, 0
	ld E, 1
	ret ; return 1
.noUnderflow
	dec B
	TODO UPTO
