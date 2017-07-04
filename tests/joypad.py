
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

JoyQueue = Memory(0, 0, 42) # empty queue, 42 used for uninitialized mem

JOY_QUEUE_SIZE = 63


read_zero_to_non_zero = Test(
	in_InterruptsEnabled = Memory(1 << 4), # Joypad interrupt enabled
	in_JoyState = Memory(0), # prev state = nothing pressed
	in__JoyTestState = Memory(1), # 'A' button pressed
	out_InterruptsEnabled = Memory(0), # Joypad interrupt disabled
	out_JoyState = Memory(1), # correctly read 'A' press and stored it
	out_JoyQueue = Memory(1, 0, 1), # written 1 to queue
)

read_non_zero_to_zero = Test(
	in_InterruptsEnabled = Memory(0), # Joypad interrupt disabled
	in_JoyState = Memory(0x10), # prev state = 'Right' pressed
	in__JoyTestState = Memory(0), # nothing pressed
	out_InterruptsEnabled = Memory(1 << 4), # Joypad interrupt enabled
	out_JoyState = Memory(0), # correctly read nothing pressed
	out_JoyQueue = Memory(1, 0, 0), # written 0 to queue
)

read_non_zero_to_non_zero = Test(
	in_InterruptsEnabled = Memory(0), # Joypad interrupt disabled
	in_JoyState = Memory(0x80), # prev state = 'Down' pressed
	in_JoyQueue = Memory(5, 4, [42]*4, 100, 42), # a queue with 1 item already present
	in__JoyTestState = Memory(0x81), # 'Down'+'A' pressed
	out_InterruptsEnabled = Memory(0), # Joypad interrupt still disabled
	out_JoyState = Memory(0x81), # correctly changed to new state
	out_JoyQueue = Memory(6, 4, [42]*4, 100, 0x81), # written new state to queue
)

# can happen due to races, we want to ensure it doesn't disable interrupt
read_zero_to_zero = Test(
	in_InterruptsEnabled = Memory(1 << 4), # Joypad interrupt enabled
	in_JoyState = Memory(0), # prev state = nothing pressed
	in__JoyTestState = Memory(0), # nothing pressed
	out_InterruptsEnabled = Memory(1 << 4), # Joypad interrupt still enabled
	out_JoyQueue = Memory(0, 0), # No value written to queue
)

queue_contents = [random.randrange(256) for _ in range(JOY_QUEUE_SIZE)]
read_with_queue_full = Test(
	in_JoyState = Memory(1), # 'A' pressed
	in__JoyTestState = Memory(3), # 'A'+'B' pressed
	in_JoyQueue = Memory(JOY_QUEUE_SIZE, 0, queue_contents),
	out_JoyState = Memory(3), # JoyState updated
	out_JoyQueue = Memory(JOY_QUEUE_SIZE, 0, queue_contents), # but JoyQueue didn't
)

joy_presses_basic = Test('T_JoyGetPress',
	in_JoyQueue = Memory(1, 0, 3), # A+B pressed
	in_C = 1, # initial state = A pressed
	out_A = 2, # output: B pressed
	out_C = 3, # final state = A+B pressed
)

joy_presses_with_release = Test('T_JoyGetPress',
	in_JoyQueue = Memory(2, 0, 2, 3), # only B pressed, then A+B pressed
	in_C = 3, # initial state = A+B pressed
	out_A = 1, # output: A pressed
	out_C = 3, # final state = A+B pressed
)
