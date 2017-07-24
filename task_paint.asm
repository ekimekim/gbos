
; A task that allows the user to paint the screen with A or B to set/clear a tile

TILE_A EQU 128+"#"
TILE_B EQU 128+" "
TILE_TEMP EQU 128 + "."


SECTION "Task Paint bootstrap", ROM0


; Since TaskPaintMain is in a ROM bank, we can't start execution there.
; We use a small shim to load the correct bank first.
TaskPaintStart::
	ld C, BANK(TaskPaintMain)
	call T_SetROMBank
	jp TaskPaintMain


SECTION "Task Paint code", ROMX


TaskPaintMain::
	xor A
	ld C, A ; C = last joy state
	ld D, A
	ld E, A ; DE = screen index

.mainloop
	; NOTE: There is nothing stopping the cursor from going off the sides of the screen
	; and screwing everything up. This code is for example and testing purposes only.
	call T_JoyGetPress

	; Check d-pad
	bit 4, A ; right pressed
	jr z, .noRight
	inc DE
.noRight
	bit 5, A ; left pressed
	jr z, .noLeft
	dec DE
.noLeft
	bit 6, A ; up pressed
	jr z, .noUp
	ld HL, -32
	add HL, DE
	ld D, H
	ld E, L ; DE -= 32
.noUp
	bit 7, A ; down pressed
	jr z, .noDown
	ld HL, 32
	add HL, DE
	ld D, H
	ld E, L ; DE += 32
.noDown

	ld B, TILE_TEMP
	; Check buttons - since A and B at once isn't meaningful, prefer A
	bit 0, A ; A pressed
	jr z, .noA
	ld B, TILE_A
	jr .gotTile
.noA
	bit 1, A ; B pressed
	jr z, .gotTile ; loop if no buttons pressed
	ld B, TILE_B

.gotTile
	; Tile to write is in B. Too bad it has to be in C, and C has state we need to keep.
	push BC
	ld C, B
	call T_GraphicsWriteTile ; Write C to index DE
	pop BC
	jr .mainloop
