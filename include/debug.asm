
DEBUG_ENABLED EQU 0

; Debug macro works in certain emulators to print a debug message \1.
; Currently supported: bgb only.
; Does nothing unless DEBUG_ENABLED flag is set to 1 above
Debug: MACRO
IF DEBUG_ENABLED > 0
	ld d, d
	jr .end\@
	dw $6464
	dw $0000
	db \1
.end\@
ENDC
ENDM
