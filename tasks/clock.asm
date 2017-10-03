include "longcalc.asm"

; A basic clock task that puts OS uptime in a specific position on screen using sprites.

; Location on screen to display
CLOCK_POS_X EQU 4
CLOCK_POS_Y EQU 4

; Sprite indexes to use (hardcoded for now). Set start of range, we use 11 sprites.
CLOCK_SPRITE_INDEX_START EQU 0

; Actual X and Y values to use
_CLOCK_POS_X EQU CLOCK_POS_X + 8
_CLOCK_POS_Y EQU CLOCK_POS_Y + 16


SECTION "Task clock code", ROMX

TaskClockMain::
.mainloop
	call TaskClockGetHMS ; BCDE = HH MM SS cc in BCD
	ld HL, CLOCK_SPRITE_INDEX_START << 8 + _CLOCK_POS_X

	ld A, B
	push DE
	push BC
	; We only display one digit of hours (let it wrap after 10 hours)
	; because we can only display 10 sprites on one line.
	and $0f
	add 128 + "0"
	call TaskClockDrawChar
	ld A, 128 + ":"
	call TaskClockDrawChar
	pop BC
	ld A, C
	call TaskClockDrawDigitPair
	ld A, 128 + ":"
	call TaskClockDrawChar
	pop DE
	push DE
	ld A, D
	call TaskClockDrawDigitPair
	ld A, 128 + "."
	call TaskClockDrawChar
	pop DE
	ld A, E
	call TaskClockDrawDigitPair

	ld DE, 16 ; 16ms ~= 1 frame
	call T_SchedSleepTask

	jr .mainloop


; Get current uptime and store in BCDE as 2-digit BCD values hours, minutes, seconds, centiseconds
; Note it will be incorrect in the hours column after 100 hours!
TaskClockGetHMS:
	call T_GetUptime ; BCDE = uptime in ticks

	; Our general approach: First, turn 32-bit ticks into 8-bit hours, mins, secs, centis.
	; Then worry about the BCD conversion.

	; Centis/seconds is the easy part, since we know that split is 10 bits in,
	; since ticks are in units of 2^-10 seconds.
	ld A, D
	and %00000011
	ld H, A
	ld L, E ; HL = bottom 10 bits of BCDE = fraction of a second in ticks
	; Now we need to shift 24-bit reg B,C,D down by 2 to get seconds
	srl B
	rr C
	rr D ; shifted once
	srl B
	rr C
	rr D ; shifted twice

	; We calculate 100 * HL / 1024 to get 100ths of a second.
	; 100 * HL / 1024 === 25 * HL / 256 -> multiply by 25 then take top byte (H)
	push DE
	ld DE, 0
	MultiplyConst16 H,L, 25, D,E ; DE = HL * 25
	ld H, D
	pop DE
	; Now H = 100ths of a second

	ld E, 60
	call TaskClockDivMod ; BCD, A = BCD / 60, BCD % 60
	ld L, A ; Now L = seconds
	call TaskClockDivMod ; BCD, A = BCD / 60, BCD % 60
	; CD = hours, A = minutes
	; We're punting on dealing with >= 100 hours sanely, so we just discard C
	; and assume D < 100.

	call TaskClockBCDConvert
	ld C, A ; C = minutes in BCD
	ld A, D
	ld D, C ; because BC will get clobbered
	call TaskClockBCDConvert
	ld B, A ; B = hours in BCD
	ld C, D
	push BC
	ld A, L
	call TaskClockBCDConvert
	ld D, A ; D = seconds in BCD
	ld A, H
	call TaskClockBCDConvert
	ld E, A ; E = centiseconds in BCD
	pop BC

	ret


; Convert A = 0 to 99 into BCD form and output in A.
; Clobbers BCE.
TaskClockBCDConvert:
	; I don't actually understand this algorithm - I found it online and it seems to work:
    ; digits all start at 0 and are 4-bit binary numbers
    ; repeat N times (where N is number of input binary number bits):
    ;   for each digit:
    ;     if digit >= 5, digit += 3
    ;   shift left, in order, with carry between them:
    ;     binary number, ones digit, tens digit, etc
	;     (eg. shift MSB of binary number into LSB of ones digit)
    ; each 4-bit digit is now a BCD digit
	; TODO I actually understand this now. Consider the 5 and 3 values AFTER they've been shifted:
	; 5 becomes 10, 3 becomes 6. So if the digit is >= 10, add 6. It's performing the same calculation
	; as the DAA instruction, and could be greatly sped up by using that instead.
	ld C, A
	ld B, 0

; arg \1 is either 0 or 4 (0 to check lower half, 4 to check upper)
; clobbers E
_Check5: MACRO
    ld A, B
    and $0f << \1
    cp 5 << \1
    jr c, .lessThan5\@
    add 3 << \1
    ld E, A
    ld A, B
    and $0f << (4 - \1) ; get opposite half
    or E ; combine with new value for this half
    ld B, A
.lessThan5\@
    ENDM

	REPT 8
	_Check5 0
	_Check5 4
	sla C
	rl B
	ENDR

	ld A, B
	ret


; Calculate divisor and modulus by E of 24-bit unsigned int in regs BCD
; Outputs divisor in BCD and modulus in A.
TaskClockDivMod:
	; This algorithm is ultimately a kind of long division in base 2.
	; We're short on registers, so we carefully manage B, C and D to set the quotient
	; even as we shift the input out.
	; The bit that is at the bottom just after we shift out bit n will become bit n after the full
	; 8 shifts is completed. Visual explanation:
	;  n1 n2 n3 n4 n5 n6 n7 n8
	;  n2 n3 n4 n5 n6 n7 n8 q1
	;  n3 n4 n5 n6 n7 n8 q1 q2
	;  n4 n5 n6 n7 n8 q1 q2 q3
	;  n5 n6 n7 n8 q1 q2 q3 q4
	;  n6 n7 n8 q1 q2 q3 q4 q5
	;  n7 n8 q1 q2 q3 q4 q5 q6
	;  n8 q1 q2 q3 q4 q5 q6 q7
	;  q1 q2 q3 q4 q5 q6 q7 q8

	xor A ; initialize remainder

; Helper macro to unroll. Takes current register to consider \1 = B, C or D.
_DivModPart: MACRO
	REPT 8
	sla \1 ; shift \1, putting the top bit into carry flag and setting bottom bit to 0
	rla ; rotate A left, doubling it and setting bottom bit depending on carry flag
	cp E ; set c if A < divisor
	jr c, .lessThanDivisor\@
	; A > divisor, set next quotient bit (bottom bit of \1) and sub divisor from A
	sub E
	inc \1 ; sets bottom bit, since we know we set it to 0 just above
.lessThanDivisor\@
	ENDR
	ENDM

	_DivModPart B
	_DivModPart C
	_DivModPart D
	; BCD now contains the quotient, and A the final remainder.
	ret


; Draw sprites for each digit of the pair of BCD digits in A
; with X position taken from L and sprite index taken from H.
; Updates H and L to next available index and X position.
; Clobbers ABCDE.
TaskClockDrawDigitPair:
	ld B, A
	and $f0
	swap A ; A = first digit value
	add 128 + "0" ; A = first digit character
	push BC
	call TaskClockDrawChar
	pop BC
	ld A, B
	and $0f ; A = second digit value
	add 128 + "0" ; A = second digit character
	jp TaskClockDrawChar


; Draw sprite with tile A at X position L, sprite index H, updating H and L to next position.
; Clobbers ABCDE.
TaskClockDrawChar:
	ld B, L
	ld C, _CLOCK_POS_Y
	ld D, A
	ld E, 0
	ld A, H
	push HL
	call T_GraphicsWriteSprite
	pop HL
	inc H
	ld A, L
	add 8
	ld L, A
	ret
