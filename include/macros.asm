
; Copy BC bytes from [HL] to [DE]. Clobbers A.
LongCopy: MACRO
.loop\@
    ld A, [HL+]
    ld [DE], A
    inc DE
    dec BC
    xor A
    cp C
    jr nz, .loop\@
    cp B
    jr nz, .loop\@
	ENDM

; Copy B bytes from [HL] to [DE]. Clobbers A.
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
	IF \2 >= 4
	swap \1
	and $f0
	N SET \2 - 4
	ELSE
	N SET \2
	ENDC
	REPT N
	srl \1
	ENDR
	PURGE N
	ENDM

; Set the ROM bank number to A
SetROMBank: MACRO
	ld [$2100], A ; I'm not entirely sure how to set the MBC type, and MBC2 doesn't like $2000
	ENDM

; Set the RAM bank number to A
SetRAMBank: MACRO
	ld [$4000], A
	ENDM
