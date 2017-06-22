
; Copy BC bytes (non-zero) from [HL] to [DE]. Clobbers A.
LongCopy: MACRO
	; adjust for an off-by-one issue in the outer loop exit condition, unless ALSO affected
	; by an error in the inner loop exit condition that adds an extra round when C = 0
	xor A
	cp C
	jr z, .loop\@
	inc B
.loop\@
	ld A, [HL+]
	ld [DE], A
	inc DE
	dec C
	jr nz, .loop\@
	dec B
	jr nz, .loop\@
	ENDM

; Copy B bytes (non-zero) from [HL] to [DE]. Clobbers A.
Copy: MACRO
.loop\@
	ld A, [HL+]
	ld [DE], A
	inc DE
	dec B
	jr nz, .loop\@
	ENDM

; Shift unsigned \1 to the right \2 times, effectively dividing by 2^N
ShiftRN: MACRO
	IF (\2) >= 4
	swap \1
	and $0f
	N SET (\2) + (-4)
	ELSE
	N SET \2
	ENDC
	REPT N
	srl \1
	ENDR
	PURGE N
	ENDM

; More efficient (for N > 1) version of ShiftRN for reg A only.
; Shifts A right \1 times.
ShiftRN_A: MACRO
	IF (\1) >= 4
	swap A
	N SET (\1) + (-4)
	ELSE
	N SET (\1)
	ENDC
	REPT N
	rra ; note this is a rotate, hence the AND below
	ENDR
	and $ff >> (\1)
	ENDM

; Set the ROM bank number to A
SetROMBank: MACRO
	ld [$2100], A ; I'm not entirely sure how to set the MBC type, and MBC2 doesn't like $2000
	ENDM

; Set the RAM bank number to A
SetRAMBank: MACRO
	ld [$4000], A
	ENDM
