
include "debug_enabled.asm"

; Debug macro works in certain emulators to print a debug message \1.
; Currently supported: bgb only.
; Does nothing unless DEBUG_ENABLED flag is set to 1 in debug_enabled.asm
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

; As Debug, but prints \2 only if condition \1 (condition same as jp instructions) is NOT met.
; eg. DebugIfNot nz, "foo" prints "foo" if z is set.
DebugIfNot: MACRO
IF DEBUG_ENABLED > 0
	jr \1, .notmet\@
	Debug \2
.notmet\@
ENDC
ENDM
