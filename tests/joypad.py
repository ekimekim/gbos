
file = "joypad"

asm = """
; This macro gets called after each write to our mock JoyIO, it reads what was written
; and updates it from _JoyTestState accordingly.
_UnitTestUpdateJoyIO: MACRO
	push AF
	push BC
	ld A, [JoyIO]
	ld B, A
	xor A
	bit 4, B
	jr nz, ._no_dpad\@
	ld A, [_JoyTestState]
	swap A
	and $0f
._no_dpad\@
	ld C, A
	xor A
	bit 5, B
	jr nz, ._no_buttons\@
	ld A, [_JoyTestState]
	and $0f
._no_buttons\@
	or C
	cpl
	ld [JoyIO], A
	pop BC
	pop AF
ENDM

SECTION "Test-specific vars", WRAM0
_JoyTestState:
	db
"""

target = 'JoyReadState'


read_zero_to_non_zero = Test(
	in_InterruptsEnabled = Memory(1 << 4), # Joypad interrupt enabled
	in_JoyState = Memory(0), # prev state = nothing pressed
	in__JoyTestState = Memory(1), # 'A' button pressed
	out_InterruptsEnabled = Memory(0), # Joypad interrupt disabled
	out_JoyState = Memory(1), # correctly read 'A' press and stored it
)

read_non_zero_to_zero = Test(
	in_InterruptsEnabled = Memory(0), # Joypad interrupt disabled
	in_JoyState = Memory(0x10), # prev state = 'Right' pressed
	in__JoyTestState = Memory(0), # nothing pressed
	out_InterruptsEnabled = Memory(1 << 4), # Joypad interrupt enabled
	out_JoyState = Memory(0), # correctly read nothing pressed
)

read_non_zero_to_non_zero = Test(
	in_InterruptsEnabled = Memory(0), # Joypad interrupt disabled
	in_JoyState = Memory(0x80), # prev state = 'Down' pressed
	in__JoyTestState = Memory(0x81), # 'Down'+'A' pressed
	out_InterruptsEnabled = Memory(0), # Joypad interrupt still disabled
	out_JoyState = Memory(0x81), # correctly changed to new state
)

# can happen due to races, we want to ensure it doesn't disable interrupt
read_zero_to_zero = Test(
	in_InterruptsEnabled = Memory(1 << 4), # Joypad interrupt enabled
	in_JoyState = Memory(0), # prev state = nothing pressed
	in__JoyTestState = Memory(0), # nothing pressed
	out_InterruptsEnabled = Memory(1 << 4), # Joypad interrupt still enabled
)
