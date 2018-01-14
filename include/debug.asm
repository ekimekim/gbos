IF !DEF(_G_DEBUG)
_G_DEBUG EQU "true"

; Debug macro works in certain emulators to print a debug message \1.
; Currently supported: bgb only.
; Does nothing unless DEBUG flag is set to 1
Debug EQUS "_Debug \{__LINE__\}, "
; _Debug takes __LINE__ as first arg as a workaround. Use Debug instead.
_Debug: MACRO
IF DEBUG > 0

	; We define the message off in some other ROM bank so that the size difference between
	; debug builds and release builds for the same section of code is small.
PUSHS
SECTION "Debug string {__FILE__} \1 \@", ROMX
DebugString\@:
	db strcat(__FILE__, strcat(":\1@%TOTALCLKS%: ", \2))
	db 0 ; null terminator
POPS

	ld d, d
	jr .end\@
	dw $6464, $0001, DebugString\@, BANK(DebugString\@)
.end\@
ENDC
ENDM

; As Debug, but prints \2 only if condition \1 (condition same as jp instructions) is NOT met.
; eg. DebugIfNot nz, "foo" prints "foo" if z is set.
DebugIfNot EQUS "_DebugIfNot \{__LINE__\}, "
_DebugIfNot: MACRO
IF DEBUG > 0
	jr \2, .notmet\@
	_Debug \1, \3
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

; Because there's often cases where something fits within a jr jump in normal builds,
; but not in debug builds, the jd macro is a jp if DEBUG is set, else a jr.
jd: MACRO
IF DEBUG > 0
	jp \1, \2
ELSE
	jr \1, \2
ENDC
ENDM

ENDC
