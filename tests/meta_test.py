"""Example test to test the testing framework"""

# Normally you'd specify a top-level directory .asm file to 'include'.
# This file should contain the target function. We 'include' it rather than linking it
# so the test can potentially access unexported ('private') labels.
# You can say None, but it's a weird case.
file = None

# What top-level directory .asm files to link with. Default is [], shown here as an example.
files = []

# function to test
target = 'TestCode'

# extra asm to add as a helper (should be rare)
asm = """
SECTION "Test Mem", WRAM0

TestMem:
	ds 5

SECTION "Test code", ROM0

; Basic function to test. Should output HL = $face, B = input B + 1,
; A = TestMem[0] + TestMem[1], TestMem[3] = TestMem[0] - TestMem[1],
; and set z iff A == TestMem[2]
TestCode:
	ld HL, $face
	inc B
	ld A, [TestMem+2]
	ld D, A
	ld A, [TestMem+1]
	ld C, A
	ld A, [TestMem]
	sub C
	ld [TestMem+3], A
	ld A, [TestMem]
	add C
	cp D
	ret
"""

# anything of type Memory is set as a default initial value for that label in memory
TestMem = Memory(5, 2, 7)

# Create a test and assign it to a name
basic = Test(
	# in_REG sets initial register states
	in_B = 42,
	# out_REG checks register states after call
	out_A = 7,
	out_HL = 0xface,
	out_B = 43,
	# in/out also works for z, c flags
	out_zflag = True,
	# out_LABEL checks contents of memory LABEL after call (as long as type is Memory)
	out_TestMem = Memory(5, 2, 7, 3),
)

no_match = Test(
	# We're leaving a lot of things unspecified here since they're tested by basic.
	# Note the in_LABEL here overrides the overlapping part of the outer TestMem definition
	in_TestMem = Memory(6),
	out_zflag = False,
)

this_fails = Test(
	out_HL = 0xcefa
)

# Currently no way to specify input/output stack, but it wouldn't be much of a change.
