
; Debug macro works in certain emulators to print a debug message \1.
; Currently supported: bgb only.
; Does nothing unless DEBUG flag is set to 1
Debug: MACRO
IF DEBUG > 0
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
IF DEBUG > 0
	jr \1, .notmet\@
	Debug \2
.notmet\@
ENDC
ENDM

; Breakpoint macro works in certain emulators to break into debugger when run.
; Currently supported: bgb only.
; Does nothing unless DEBUG flag is set to 1
Breakpoint: MACRO
IF DEBUG > 0
	ld b, b
ENDC
ENDM

; As Breakpoint, but breaks only if condition \1 (same as jp instructions) is NOT met
BreakpointIfNot: MACRO
IF DEBUG > 0
	jr \1, .notmet\@
	Breakpoint
.notmet\@
ENDC
ENDM
