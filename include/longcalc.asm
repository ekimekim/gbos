
; Macro file containing macros for calculations involving long (16-bit) numbers

; Copy value in reg pair \3\4 to \1\2
LongLoad: MACRO
	ld \1, \3
	ld \2, \4
	ENDM

; Add 16-bit reg pairs or immediates \1\2 and \3\4, putting result in \5\6, which may be the same as either.
; Cannot use AF. Clobbers A. Sets or resets carry as per normal add.
; \1\2 and \5\6 may be indirect immediates.
LongAdd: MACRO
	ld A, \2
	add \4
	ld \6, A
	ld A, \1
	adc \3
	ld \5, A
	ENDM

; Subtract 16-bit reg pairs or immediates \1\2 and \3\4, putting result in \5\6, which may be the same as either.
; Cannot use AF. Clobbers A. Sets or resets carry as per normal subtract.
LongSub: MACRO
	ld A, \2
	sub \4
	ld \6, A
	ld A, \1
	sbc \3
	ld \5, A
	ENDM

; Shift 16-bit reg pair \1\2 (not AF) left once. Sets carry as per normal shift.
; This corresponds to doubling the (unsigned) value.
LongShiftL: MACRO
	sla \2
	rl \1
	ENDM

; Shift 16-bit reg pair \1\2 (not AF) right once. Highest order bit in result is 0.
; This corresponds to halving the (unsigned) value, rounding down.
; Sets carry flag true if there was a remainder.
LongShiftR: MACRO
	srl \1
	rr \2
	ENDM
