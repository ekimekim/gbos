IF !DEF(_G_LONGCALC)
_G_LONGCALC EQU "true"


; Macro file containing macros for calculations involving long (16-bit) numbers

; Copy value in reg pair \3\4 to \1\2
LongLoad: MACRO
	ld \1, \3
	ld \2, \4
	ENDM

; Add 16-bit reg pairs or immediates \1\2 and \3\4, putting result in \5\6, which may be the same as either.
; \1 and \2 may also be indirect immediates.
; Cannot use AF. Clobbers A. Sets or resets carry as per normal add.
; \1\2 and \5\6 may be indirect immediates.
; Note: In the case where \1\2 and \5\6 are HL and \3\4 are BC or DE, you should use "ADD HL, rr" instead.
LongAddParts: MACRO
	ld A, \2
	add \4
	ld \6, A
	ld A, \1
	adc \3
	ld \5, A
	ENDM

; Helper to LongAddParts that takes 16-bit immediates or reg pairs \1, \2, \3
; such that \3 = \1 + \2
LongAdd: MACRO
	LongAddParts HIGH(\1),LOW(\1), HIGH(\2),LOW(\2), HIGH(\3),LOW(\3)
ENDM

; Add 16-bit reg pair or immediate \1\2 to A, putting result in \3\4, which may be the same as \1\2.
; Clobbers A. Sets or resets carry as per normal add.
LongAddToAParts: MACRO
	add \2
	ld \4, A
	ld A, 0 ; this can't be xor A because that would reset carry
	adc \1
	ld \3, A
	ENDM

; Helper to LongAddParts that takes 16-bit immediates or reg pairs \1, \2
; such that \2 = A + \1
LongAddToA: MACRO
	LongAddToAParts HIGH(\1),LOW(\1), HIGH(\2),LOW(\2)
ENDM

; An alternate approach to LongAdd, suitable for very small const in-place addition to a 16-bit reg.
; (compared to a LongAdd \1,\2,\1, faster for abs(\2) <= 4 and smaller for <= 8)
; (only faster than 'ld \1, immediate' for abs(\2) <= 1 and smaller for <= 3)
; \1 is target reg, \2 is const amount to add (positive or negative)
LongAddConst: MACRO
IF (\2) >= 0
OP EQUS "inc"
N EQU \2
ELSE
OP EQUS "dec"
N EQU -(\2)
ENDC
REPT N
	OP \1
ENDR
PURGE OP,N
	ENDM

; Given some address stored in \1 pointing to struct field \2, modify \1 to point at field \3 instead
RepointStruct: MACRO
	LongAddConst \1, (\3) - (\2)
	ENDM

; Subtract 16-bit reg pairs or immediates \1\2 and \3\4, putting result in \5\6, which may be the same as either.
; Cannot use AF. Clobbers A. Sets or resets carry as per normal subtract.
LongSubParts: MACRO
	ld A, \2
	sub \4
	ld \6, A
	ld A, \1
	sbc \3
	ld \5, A
	ENDM
LongSub: MACRO
	LongSubParts HIGH(\1),LOW(\1), HIGH(\2),LOW(\2), HIGH(\3),LOW(\3)
	ENDM

; Compare 16-bit reg pairs or immediates \1\2 and \3\4, setting zero and carry as per normal cp.
; Clobbers A.
LongCPParts: MACRO
	ld A, \2
	sub \4
	ld A, \1
	sbc \3
	ENDM
LongCP: MACRO
	LongCPParts HIGH(\1),LOW(\1), HIGH(\2),LOW(\2)
ENDM

; Shift 16-bit reg pair \1\2 (not AF) left once. Sets carry as per normal shift.
; This corresponds to doubling the (unsigned) value.
; Note: If you simply want to double HL, "ADD HL, HL" is faster but has different flag effects.
LongShiftLParts: MACRO
	sla \2
	rl \1
	ENDM
LongShiftL: MACRO
	LongShiftLParts HIGH(\1), LOW(\1)
ENDM

; Shift 16-bit reg pair \1\2 (not AF) right once. Highest order bit in result is 0.
; This corresponds to halving the (unsigned) value, rounding down.
; Sets carry flag true if there was a remainder.
LongShiftRParts: MACRO
	srl \1
	rr \2
	ENDM
LongShiftR: MACRO
	LongShiftRParts HIGH(\1), LOW(\1)
ENDM


; Multiply 16-bit reg pair \1 by 8-bit immediate \2, adding result to reg pair \3,
; ie. \3 += \1 * \2.
; The result pair MUST NOT be the same as the input pair.
; Overflow is undefined - you must ensure your maximum value * \2 < 65536.
; This is considerably fast because it's fully unrolled and hard-codes the multiplier,
; so it can straight up omit any steps that aren't needed for that number.
; Clobbers A, \1
MultiplyConst16: MACRO
_N SET \2
	REPT 8
	IF _N & 1 > 0
	LongAdd \3, \1, \3
	ENDC
_N SET _N >> 1
	IF _N > 0
	LongShiftL \1
	ENDC
	ENDR
	ENDM

ENDC
